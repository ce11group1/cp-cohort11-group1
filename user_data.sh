#!/bin/bash

# Update and install dependencies
yum update -y
yum install -y python3 pip git amazon-ssm-agent
systemctl enable amazon-ssm-agent
systemctl start amazon-ssm-agent

pip3 install AWSIoTPythonSDK

# Create working directory
mkdir -p /iot
cd /iot

#########################################
# Generate simulator.py dynamically
#########################################

cat <<EOF > /iot/simulator.py
import json
import time
import random
from AWSIoTPythonSDK.MQTTLib import AWSIoTMQTTClient

ENDPOINT = "${iot_endpoint}"
PREFIX = "${prefix}"
ENV = "${env}"

CLIENT_ID = f"{PREFIX}-{ENV}-sim"
TOPIC = f"{PREFIX}/{ENV}/data"

client = AWSIoTMQTTClient(CLIENT_ID)
client.configureEndpoint(ENDPOINT, 8883)
client.configureCredentials("/iot/AmazonRootCA1.pem", "/iot/private.key", "/iot/certificate.pem")
client.configureOfflinePublishQueueing(-1)
client.configureConnectDisconnectTimeout(10)
client.configureMQTTOperationTimeout(5)

print("Connecting to AWS IoT Core...")
client.connect()
print("Connected.")

while True:
    payload = {
        "device_id": f"{PREFIX}-{ENV}-device",
        "temperature": round(random.uniform(20, 45), 2),
        "humidity": round(random.uniform(40, 80), 2),
        "timestamp": int(time.time())
    }
    client.publish(TOPIC, json.dumps(payload), 1)
    print("Published:", payload)
    time.sleep(5)
EOF

#########################################
# Fetch IoT certificates from SSM
#########################################

wget https://www.amazontrust.com/repository/AmazonRootCA1.pem -O /iot/AmazonRootCA1.pem

aws ssm get-parameter --name "/iot/${prefix}/${env}/cert" --with-decryption --query "Parameter.Value" --output text > /iot/certificate.pem
aws ssm get-parameter --name "/iot/${prefix}/${env}/key" --with-decryption --query "Parameter.Value" --output text > /iot/private.key

chmod 600 /iot/private.key

#########################################
# Create systemd service for persistence
#########################################

cat <<EOF > /etc/systemd/system/iot-simulator.service
[Unit]
Description=AWS IoT Simulator Service
After=network.target

[Service]
ExecStart=/usr/bin/python3 /iot/simulator.py
WorkingDirectory=/iot
Restart=always
StandardOutput=append:/iot/simulator.log
StandardError=append:/iot/simulator.log

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable iot-simulator
systemctl start iot-simulator
