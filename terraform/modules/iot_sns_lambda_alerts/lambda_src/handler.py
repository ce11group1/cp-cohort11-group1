import json
import boto3
import os

sns = boto3.client("sns")
TOPIC_ARN = os.environ["SNS_TOPIC_ARN"]
PREFIX = os.environ["PREFIX"]
ENV = os.environ["ENV"]

def lambda_handler(event, context):
    # IoT can deliver single or batch events depending on rule config
    # We just log and send the whole thing out.
    print("Received event:", json.dumps(event))

    subject = f"IoT Threshold Alert - {PREFIX}-{ENV}"
    message = {
        "prefix": PREFIX,
        "env": ENV,
        "alert": "Monitored stats went out of threshold",
        "event": event
    }

    sns.publish(
        TopicArn=TOPIC_ARN,
        Subject=subject,
        Message=json.dumps(message, indent=2)
    )

    return {
        "status": "alert_sent",
        "subject": subject
    }
