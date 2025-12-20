import json
import os
import time
from datetime import datetime, timezone, timedelta
from typing import List, Dict, Any, Tuple

import boto3
import numpy as np
import pandas as pd
from scipy.stats import ks_2samp

AWS_REGION = os.getenv("AWS_REGION", "us-east-1")
S3_BUCKET = os.environ["S3_BUCKET"]
TELEMETRY_PREFIX = os.getenv("TELEMETRY_PREFIX", "telemetry/")
BASELINE_KEY = os.getenv("BASELINE_KEY", "ml/baseline/baseline.json")
DRIFT_STATUS_KEY = os.getenv("DRIFT_STATUS_KEY", "ml/drift/drift_status.json")

FEATURES = os.getenv("FEATURES", "temperature,humidity").split(",")
WINDOW_MINUTES = int(os.getenv("WINDOW_MINUTES", "60"))
PSI_THRESHOLD = float(os.getenv("PSI_THRESHOLD", "0.2"))
KS_P_THRESHOLD = float(os.getenv("KS_P_THRESHOLD", "0.05"))

# Retrain trigger settings
TRIGGER_RETRAIN = os.getenv("TRIGGER_RETRAIN", "true").lower() == "true"
ECS_CLUSTER = os.getenv("ECS_CLUSTER", "")
RETRAIN_TASK_DEF = os.getenv("RETRAIN_TASK_DEF", "")
SUBNETS = os.getenv("SUBNETS", "")           # comma-separated
SECURITY_GROUPS = os.getenv("SECURITY_GROUPS", "")  # comma-separated
ASSIGN_PUBLIC_IP = os.getenv("ASSIGN_PUBLIC_IP", "true").lower() == "true"

s3 = boto3.client("s3", region_name=AWS_REGION)
ecs = boto3.client("ecs", region_name=AWS_REGION)


def list_recent_objects(prefix: str, since: datetime) -> List[str]:
    keys = []
    token = None
    while True:
        kwargs = dict(Bucket=S3_BUCKET, Prefix=prefix, MaxKeys=1000)
        if token:
            kwargs["ContinuationToken"] = token
        resp = s3.list_objects_v2(**kwargs)
        for obj in resp.get("Contents", []):
            if obj["LastModified"] >= since:
                keys.append(obj["Key"])
        if not resp.get("IsTruncated"):
            break
        token = resp.get("NextContinuationToken")
    return keys


def load_json_lines(keys: List[str]) -> List[Dict[str, Any]]:
    rows = []
    for k in keys:
        try:
            obj = s3.get_object(Bucket=S3_BUCKET, Key=k)
            data = obj["Body"].read().decode("utf-8")
            rows.append(json.loads(data))
        except Exception:
            continue
    return rows


def psi(expected: np.ndarray, actual: np.ndarray, bins: int = 10) -> float:
    # Avoid empty
    if len(expected) < 5 or len(actual) < 5:
        return 0.0

    # quantile bins based on expected
    quantiles = np.quantile(expected, np.linspace(0, 1, bins + 1))
    quantiles = np.unique(quantiles)
    if len(quantiles) < 3:
        return 0.0

    exp_counts, _ = np.histogram(expected, bins=quantiles)
    act_counts, _ = np.histogram(actual, bins=quantiles)

    exp_perc = exp_counts / max(exp_counts.sum(), 1)
    act_perc = act_counts / max(act_counts.sum(), 1)

    eps = 1e-6
    exp_perc = np.clip(exp_perc, eps, None)
    act_perc = np.clip(act_perc, eps, None)

    return float(np.sum((act_perc - exp_perc) * np.log(act_perc / exp_perc)))


def read_baseline() -> Dict[str, List[float]]:
    obj = s3.get_object(Bucket=S3_BUCKET, Key=BASELINE_KEY)
    base = json.loads(obj["Body"].read().decode("utf-8"))
    return base["baseline"]


def write_drift_status(status: Dict[str, Any]):
    s3.put_object(
        Bucket=S3_BUCKET,
        Key=DRIFT_STATUS_KEY,
        Body=json.dumps(status, indent=2).encode("utf-8"),
        ContentType="application/json",
    )


def trigger_retrain():
    if not (ECS_CLUSTER and RETRAIN_TASK_DEF and SUBNETS and SECURITY_GROUPS):
        print("[drift] Missing ECS config; cannot trigger retrain.")
        return

    net = {
        "awsvpcConfiguration": {
            "subnets": [s.strip() for s in SUBNETS.split(",") if s.strip()],
            "securityGroups": [s.strip() for s in SECURITY_GROUPS.split(",") if s.strip()],
            "assignPublicIp": "ENABLED" if ASSIGN_PUBLIC_IP else "DISABLED",
        }
    }
    resp = ecs.run_task(
        cluster=ECS_CLUSTER,
        taskDefinition=RETRAIN_TASK_DEF,
        launchType="FARGATE",
        networkConfiguration=net,
    )
    failures = resp.get("failures", [])
    if failures:
        print(f"[drift] Retrain run_task failures: {failures}")
    else:
        print("[drift] Retrain task triggered.")


def main():
    now = datetime.now(timezone.utc)
    since = now - timedelta(minutes=WINDOW_MINUTES)
    keys = list_recent_objects(TELEMETRY_PREFIX, since)
    rows = load_json_lines(keys)
    df = pd.DataFrame(rows)

    drift_details = {}
    drift_detected = False

    try:
        baseline = read_baseline()
    except Exception as e:
        # No baseline yet: create baseline from current window (bootstrapping)
        baseline = {f: df[f].dropna().astype(float).tolist() for f in FEATURES if f in df.columns}
        s3.put_object(
            Bucket=S3_BUCKET,
            Key=BASELINE_KEY,
            Body=json.dumps({"created_at": now.isoformat(), "baseline": baseline}).encode("utf-8"),
            ContentType="application/json",
        )
        status = {
            "checked_at": now.isoformat(),
            "drift_detected": False,
            "reason": "baseline_created",
            "window_minutes": WINDOW_MINUTES,
            "samples": int(len(df)),
            "details": {},
        }
        write_drift_status(status)
        print("[drift] Baseline created; no drift check this run.")
        return

    for f in FEATURES:
        if f not in df.columns or f not in baseline:
            continue
        exp = np.array(baseline[f], dtype=float)
        act = df[f].dropna().astype(float).to_numpy()
        if len(act) < 10 or len(exp) < 10:
            continue

        psi_val = psi(exp, act)
        ks_stat, ks_p = ks_2samp(exp, act)

        feature_drift = (psi_val >= PSI_THRESHOLD) or (ks_p <= KS_P_THRESHOLD)
        if feature_drift:
            drift_detected = True

        drift_details[f] = {
            "psi": psi_val,
            "ks_pvalue": float(ks_p),
            "ks_stat": float(ks_stat),
            "feature_drift": feature_drift,
        }

    status = {
        "checked_at": now.isoformat(),
        "drift_detected": drift_detected,
        "window_minutes": WINDOW_MINUTES,
        "samples": int(len(df)),
        "thresholds": {"psi": PSI_THRESHOLD, "ks_pvalue": KS_P_THRESHOLD},
        "details": drift_details,
    }

    write_drift_status(status)
    print(f"[drift] Drift detected: {drift_detected}")

    if drift_detected and TRIGGER_RETRAIN:
        trigger_retrain()


if __name__ == "__main__":
    main()
