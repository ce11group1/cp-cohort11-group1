#!/bin/bash
set -e

# --- Configuration ---
CERTS_DIR="../../resources/certs"
CERT_FILE="${CERTS_DIR}/device-certificate.pem.crt"
KEY_FILE="${CERTS_DIR}/private.pem.key"
ROOT_CA_FILE="${CERTS_DIR}/AmazonRootCA1.pem"
ROOT_CA_URL="https://www.amazontrust.com/repository/AmazonRootCA1.pem"

echo "---------------------------------------------------------"
echo "🔄 Starting Certificate Extraction..."
echo "---------------------------------------------------------"

# 1. Check Pre-requisites
if ! command -v jq &> /dev/null; then
    echo "❌ Error: 'jq' is not installed."
    exit 1
fi

if [ ! -d "$CERTS_DIR" ]; then
    echo "❌ Error: Directory $CERTS_DIR does not exist."
    exit 1
fi

# 2. Extract Device Cert & Private Key (From Terraform State)
echo "📜 Extracting Device Certificate..."
terraform state pull | jq -r '.resources[] | select(.module=="module.app.module.iot") | select(.type=="aws_iot_certificate") | .instances[0].attributes.certificate_pem' > "$CERT_FILE"

echo "🔑 Extracting Private Key..."
terraform state pull | jq -r '.resources[] | select(.module=="module.app.module.iot") | select(.type=="aws_iot_certificate") | .instances[0].attributes.private_key' > "$KEY_FILE"

# 3. Check/Download Root CA (Static File)
if [ ! -f "$ROOT_CA_FILE" ]; then
    echo "🌐 Root CA not found. Downloading from AWS..."
    curl -s -o "$ROOT_CA_FILE" "$ROOT_CA_URL"
else
    echo "✅ Root CA already exists."
fi

# 4. Validation
if [ ! -s "$CERT_FILE" ] || [ ! -s "$KEY_FILE" ] || [ ! -s "$ROOT_CA_FILE" ]; then
    echo "❌ Error: One or more certificate files are empty."
    exit 1
fi

# 5. Permission Fix
chmod 600 "$KEY_FILE"

echo "---------------------------------------------------------"
echo "✅ Success! All 3 files are ready in $CERTS_DIR:"
ls -l "$CERTS_DIR"
echo "---------------------------------------------------------"
echo "NEXT STEPS:"
echo "1. Run: terraform apply -var-file=\"terraform.tfvars\""
echo "2. Run: aws ecs update-service --cluster grp1-ce11-dev-iot-cluster --service dev-iot-service --force-new-deployment --region us-east-1"
echo "---------------------------------------------------------"