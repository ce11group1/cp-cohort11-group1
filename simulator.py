import json
import time
import random
from AWSIoTPythonSDK.MQTTLib import AWSIoTMQTTClient

# --------------------------------------------------------------------
# Configuration injected from Terraform user_data.sh
# --------------------------------------------------------------------
ENDPOINT = "${iot_endpoint}"
PREFIX = "${prefix}"
ENV = "${env}"

CLIENT_ID = f"{PREFIX}-{ENV}-simulator"
TOPIC = f"{PREFIX}/{ENV}/data"

# Standard thresholds
THRESHOLDS = {
    "temperature_min": 18,
    "temperature_max": 48,   # alert only > 48°C
    "humidity_min": 30,
    "humidity_max": 90,      # alert only > 90%
    "pressure_min": 980,
    "pressure_max": 1035,    # alert only > 1035
    "battery_min": 40,       # alert only < 40%
    "battery_max": 100
}

# Warning threshold = 90% of max values
WARN_MULTIPLIER = 0.95

WARN_THRESHOLDS = {
    "temperature_high": THRESHOLDS["temperature_max"] * WARN_MULTIPLIER,
    "humidity_high":    THRESHOLDS["humidity_max"] * WARN_MULTIPLIER,
    "pressure_high":    THRESHOLDS["pressure_max"] * WARN_MULTIPLIER,
    "battery_high":     THRESHOLDS["battery_max"] * WARN_MULTIPLIER,
}

# --------------------------------------------------------------------
# Setup MQTT
# --------------------------------------------------------------------
client = AWSIoTMQTTClient(CLIENT_ID)
client.configureEndpoint(ENDPOINT, 8883)
client.configureCredentials(
    "/iot/AmazonRootCA1.pem",
    "/iot/private.key",
    "/iot/certificate.pem"
)
client.configureOfflinePublishQueueing(-1)
client.configureConnectDisconnectTimeout(10)
client.configureMQTTOperationTimeout(5)

print("Connecting to AWS IoT Core...")
client.connect()
print(f"Connected! Publishing to topic: {TOPIC}\n")

# --------------------------------------------------------------------
# Helper: threshold detection
# --------------------------------------------------------------------
def detect_thresholds(sensor):
    alerts = {}

    # High alerts
    alerts["temperature_high"] = sensor["temperature"] > WARN_THRESHOLDS["temperature_high"]
    alerts["humidity_high"]    = sensor["humidity"] > WARN_THRESHOLDS["humidity_high"]
    alerts["pressure_high"]    = sensor["pressure"] > WARN_THRESHOLDS["pressure_high"]
    alerts["battery_high"]     = sensor["battery"] > WARN_THRESHOLDS["battery_high"]

    # Low alerts
    alerts["temperature_low"]  = sensor["temperature"] < THRESHOLDS["temperature_min"]
    alerts["humidity_low"]     = sensor["humidity"] < THRESHOLDS["humidity_min"]
    alerts["pressure_low"]     = sensor["pressure"] < THRESHOLDS["pressure_min"]
    alerts["battery_low"]      = sensor["battery"] < THRESHOLDS["battery_min"]

    alerts["threshold_breached"] = any(alerts.values())
    return alerts


# --------------------------------------------------------------------
# MAIN LOOP (5 min interval)  
# Inject anomaly once per hour (12 cycles × 5 min)
# --------------------------------------------------------------------
cycle = 0
ANOMALY_INTERVAL = 12      # 12 × 5 minutes = 60 minutes
SLEEP_SECONDS = 300        # 5 minutes

while True:
    cycle += 1
    anomaly = (cycle % ANOMALY_INTERVAL == 0)

    if anomaly:
        print("\n⚠️ Injecting anomaly event (rare—once per hour)...\n")

        # Abnormal readings
        sensor = {
            "device_id": f"{PREFIX}-{ENV}-device",
            "temperature": round(random.uniform(48.0, 60.0), 2),  # above max
            "humidity": round(random.uniform(92.0, 100.0), 2),    # above max
            "pressure": round(random.uniform(1035.0, 1055.0), 2), # above max
            "battery": random.randint(10, 40),                    # below min
            "timestamp": int(time.time())
        }
    else:
        # Normal safe telemetry
        sensor = {
            "device_id": f"{PREFIX}-{ENV}-device",
            "temperature": round(random.uniform(22.0, 32.0), 2),
            "humidity": round(random.uniform(45.0, 65.0), 2),
            "pressure": round(random.uniform(990.0, 1015.0), 2),
            "battery": random.randint(70, 100),
            "timestamp": int(time.time())
        }

    alerts = detect_thresholds(sensor)
    payload = {**sensor, **alerts}

    client.publish(TOPIC, json.dumps(payload), 1)
    print("Published:", json.dumps(payload, indent=2))

    if anomaly:
        print("⚠️ ALERT: Anomaly triggered → Lambda → SNS\n")

    time.sleep(SLEEP_SECONDS)
