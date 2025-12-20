import json
import os
import time
from dataclasses import dataclass
from typing import Optional, Dict, Any

import boto3
import joblib
import numpy as np
from flask import Flask, request, jsonify
from prometheus_client import Counter, Gauge, generate_latest, CONTENT_TYPE_LATEST

AWS_REGION = os.getenv("AWS_REGION", "us-east-1")
S3_BUCKET = os.environ["S3_BUCKET"]
MODEL_LATEST_KEY = "ml/models/latest.json"
DRIFT_STATUS_KEY = "ml/drift/drift_status.json"

FEATURES = [f.strip() for f in os.getenv("FEATURES", "temperature,humidity").split(",")]

s3 = boto3.client("s3", region_name=AWS_REGION)

app = Flask(__name__)

# ---------- Metrics ----------
anomaly_total = Counter("anomaly_total", "Total anomalies detected")
score_requests_total = Counter("score_requests_total", "Total scoring requests")
model_reload_total = Counter("model_reload_total", "Model reloads", ["status"])
model_type_gauge = Gauge("model_type_id", "1=IF, 2=OCSVM")
model_score_gauge = Gauge("model_selection_score", "Model selection score")
drift_detected_gauge = Gauge("drift_detected", "Drift detected flag")


@dataclass
class ModelBundle:
    model: Any
    scaler: Any
    model_type: str
    features: list
    score: float
    key: str


MODEL: Optional[ModelBundle] = None


def load_latest_model() -> Optional[ModelBundle]:
    try:
        ptr = json.loads(s3.get_object(Bucket=S3_BUCKET, Key=MODEL_LATEST_KEY)["Body"].read())
        model_key = ptr["model_key"]
        tmp = "/tmp/model.joblib"
        s3.download_file(S3_BUCKET, model_key, tmp)

        art = joblib.load(tmp)
        bundle = ModelBundle(
            model=art["model"],
            scaler=art.get("scaler"),
            model_type=art.get("model_type", "unknown"),
            features=art.get("features", FEATURES),
            score=float(art.get("selection_score", 0.0)),
            key=model_key,
        )

        model_type_gauge.set(1 if bundle.model_type == "isolation_forest" else 2)
        model_score_gauge.set(bundle.score)
        model_reload_total.labels("ok").inc()
        return bundle

    except Exception as e:
        model_reload_total.labels("fail").inc()
        print("[scorer] model load failed:", e)
        return None


def read_drift() -> int:
    try:
        return int(json.loads(
            s3.get_object(Bucket=S3_BUCKET, Key=DRIFT_STATUS_KEY)["Body"].read()
        ).get("drift_detected", False))
    except Exception:
        return 0


@app.get("/metrics")
def metrics():
    drift_detected_gauge.set(read_drift())
    return generate_latest(), 200, {"Content-Type": CONTENT_TYPE_LATEST}


@app.post("/score")
def score():
    global MODEL
    score_requests_total.inc()

    if MODEL is None:
        MODEL = load_latest_model()
    if MODEL is None:
        return jsonify({"error": "model not loaded"}), 503

    payload = request.get_json(force=True)
    X = np.array([[float(payload.get(f, 0.0)) for f in MODEL.features]])

    if MODEL.scaler is not None:
        X = MODEL.scaler.transform(X)

    pred = MODEL.model.predict(X)[0]
    anomaly = int(pred) == -1
    if anomaly:
        anomaly_total.inc()

    return jsonify({
        "anomaly": anomaly,
        "model_type": MODEL.model_type,
        "model_key": MODEL.key,
        "selection_score": MODEL.score,
    })
