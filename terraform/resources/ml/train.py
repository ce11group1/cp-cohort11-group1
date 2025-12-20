import json
import os
import time
from datetime import datetime, timezone, timedelta
from typing import List, Dict, Any, Tuple

import boto3
import joblib
import numpy as np
import pandas as pd
from sklearn.ensemble import IsolationForest
from sklearn.svm import OneClassSVM
from sklearn.preprocessing import StandardScaler

AWS_REGION = os.getenv("AWS_REGION", "us-east-1")
S3_BUCKET = os.environ["S3_BUCKET"]
TELEMETRY_PREFIX = os.getenv("TELEMETRY_PREFIX", "telemetry/")

FEATURES = [f.strip() for f in os.getenv("FEATURES", "temperature,humidity").split(",")]
WINDOW_MINUTES = int(os.getenv("WINDOW_MINUTES", "240"))
TARGET_INLIER = float(os.getenv("TARGET_INLIER", "0.95"))

MODEL_PREFIX = "ml/models/"
MODEL_LATEST_KEY = "ml/models/latest.json"

s3 = boto3.client("s3", region_name=AWS_REGION)


def list_recent_objects(prefix: str, since: datetime) -> List[str]:
    keys = []
    token = None
    while True:
        resp = s3.list_objects_v2(
            Bucket=S3_BUCKET,
            Prefix=prefix,
            ContinuationToken=token if token else None
        )
        for obj in resp.get("Contents", []):
            if obj["LastModified"] >= since:
                keys.append(obj["Key"])
        if not resp.get("IsTruncated"):
            break
        token = resp.get("NextContinuationToken")
    return keys


def load_json_objects(keys: List[str]) -> pd.DataFrame:
    rows = []
    for k in keys:
        try:
            obj = s3.get_object(Bucket=S3_BUCKET, Key=k)
            rows.append(json.loads(obj["Body"].read()))
        except Exception:
            pass
    return pd.DataFrame(rows)


def stability_score(pred: np.ndarray) -> float:
    inlier_frac = np.mean(pred == 1)
    return -abs(inlier_frac - TARGET_INLIER)


def tail_separation(scores: np.ndarray) -> float:
    if len(scores) < 50:
        return 0.0
    return np.median(scores) - np.quantile(scores, 0.05)


def composite_score(pred: np.ndarray, scores: np.ndarray) -> float:
    return stability_score(pred) + 0.5 * tail_separation(scores)


def main():
    now = datetime.now(timezone.utc)
    since = now - timedelta(minutes=WINDOW_MINUTES)

    keys = list_recent_objects(TELEMETRY_PREFIX, since)
    df = load_json_objects(keys)

    if df.empty:
        raise RuntimeError("No telemetry found")

    X = df[FEATURES].astype(float).to_numpy()
    if X.shape[0] < 80:
        raise RuntimeError("Not enough samples for training")

    scaler = StandardScaler()
    Xs = scaler.fit_transform(X)

    candidates = []

    # ----- IsolationForest grid -----
    iso_grid = [
        {"n_estimators": 100, "contamination": 0.02},
        {"n_estimators": 200, "contamination": 0.05},
        {"n_estimators": 300, "contamination": 0.05},
    ]

    for hp in iso_grid:
        model = IsolationForest(random_state=42, **hp)
        model.fit(X)
        pred = model.predict(X)
        scores = model.decision_function(X)
        candidates.append(("isolation_forest", model, None, hp, composite_score(pred, scores)))

    # ----- OneClassSVM grid -----
    oc_grid = [
        {"nu": 0.02, "gamma": "scale"},
        {"nu": 0.05, "gamma": "scale"},
        {"nu": 0.10, "gamma": 0.1},
    ]

    for hp in oc_grid:
        model = OneClassSVM(kernel="rbf", **hp)
        model.fit(Xs)
        pred = model.predict(Xs)
        scores = model.decision_function(Xs)
        candidates.append(("oneclass_svm", model, scaler, hp, composite_score(pred, scores)))

    model_type, model, scaler_obj, hp, score = max(candidates, key=lambda x: x[-1])

    artifact = {
        "model_type": model_type,
        "trained_at": now.isoformat(),
        "features": FEATURES,
        "hyperparams": hp,
        "selection_score": float(score),
        "scaler": scaler_obj,
        "model": model,
        "samples": int(X.shape[0]),
    }

    tmp = "/tmp/model.joblib"
    joblib.dump(artifact, tmp)

    model_key = f"{MODEL_PREFIX}model_{int(time.time())}.joblib"
    s3.upload_file(tmp, S3_BUCKET, model_key)

    s3.put_object(
        Bucket=S3_BUCKET,
        Key=MODEL_LATEST_KEY,
        Body=json.dumps({"model_key": model_key, "updated_at": now.isoformat()})
    )

    print(f"[train] Best model={model_type} hp={hp} score={score}")


if __name__ == "__main__":
    main()
