#!/bin/bash
# scripts/set-grafana-smtp-secret.sh

# 1. Validate that the required environment variables are set
if [[ -z "$SMTP_USER" || -z "$SMTP_PASSWORD" ]]; then
  echo "Error: SMTP_USER and SMTP_PASSWORD environment variables must be set."
  exit 1
fi

SECRET_NAME="grafana/smtp"
REGION="us-east-1"

# 2. Construct the JSON string securely using jq
# This prevents issues with special characters in passwords
SECRET_STRING=$(jq -n \
                  --arg user "$SMTP_USER" \
                  --arg password "$SMTP_PASSWORD" \
                  --arg host "smtp.gmail.com:587" \
                  --arg from "$SMTP_USER" \
                  --arg name "IoT Factory Simulator" \
                  '{
                    SMTP_USER: $user,
                    SMTP_PASSWORD: $password,
                    SMTP_HOST: $host,
                    SMTP_FROM: $from,
                    SMTP_NAME: $name
                  }')

# 3. Check if secret exists
echo "Checking if secret $SECRET_NAME exists in $REGION..."
aws secretsmanager describe-secret \
  --secret-id "$SECRET_NAME" \
  --region "$REGION" >/dev/null 2>&1

if [ $? -eq 0 ]; then
  echo "Secret $SECRET_NAME exists. Updating value..."
  aws secretsmanager put-secret-value \
    --secret-id "$SECRET_NAME" \
    --secret-string "$SECRET_STRING" \
    --region "$REGION"
else
  echo "Secret $SECRET_NAME not found. Creating..."
  aws secretsmanager create-secret \
    --name "$SECRET_NAME" \
    --secret-string "$SECRET_STRING" \
    --region "$REGION"
fi