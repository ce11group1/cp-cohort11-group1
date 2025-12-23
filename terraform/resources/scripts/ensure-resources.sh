#!/bin/bash
set -e # Exit immediately if a command exits with a non-zero status

# Usage: ./ensure-resources.sh <BUCKET_NAME> <DYNAMODB_TABLE_NAME> <REGION>

BUCKET_NAME=$1
TABLE_NAME=$2
REGION=${3:-us-east-1}

if [ -z "$BUCKET_NAME" ] || [ -z "$TABLE_NAME" ]; then
  echo "Usage: $0 <bucket-name> <dynamodb-table-name> [region]"
  exit 1
fi

echo "----------------------------------------------------------------"
echo "Initializing Terraform Backend Resources in $REGION"
echo "Bucket: $BUCKET_NAME"
echo "Table:  $TABLE_NAME"
echo "----------------------------------------------------------------"

# ==========================================
# 1. ENSURE S3 BUCKET EXISTS
# ==========================================
echo "[S3] Checking if bucket '$BUCKET_NAME' exists..."

if aws s3api head-bucket --bucket "$BUCKET_NAME" 2>/dev/null; then
  echo "✅ [S3] Bucket '$BUCKET_NAME' already exists."
else
  echo "⚠️ [S3] Bucket '$BUCKET_NAME' not found. Creating..."
  
  if [ "$REGION" == "us-east-1" ]; then
    aws s3api create-bucket --bucket "$BUCKET_NAME" --region "$REGION"
  else
    aws s3api create-bucket \
      --bucket "$BUCKET_NAME" \
      --region "$REGION" \
      --create-bucket-configuration LocationConstraint="$REGION"
  fi

  # Enable Versioning (Highly Recommended for State Files)
  echo "   [S3] Enabling versioning..."
  aws s3api put-bucket-versioning --bucket "$BUCKET_NAME" --versioning-configuration Status=Enabled
  
  echo "✅ [S3] Bucket created successfully."
fi

# ==========================================
# 2. ENSURE DYNAMODB TABLE EXISTS
# ==========================================
echo "[DynamoDB] Checking if table '$TABLE_NAME' exists..."

if aws dynamodb describe-table --table-name "$TABLE_NAME" --region "$REGION" >/dev/null 2>&1; then
  echo "✅ [DynamoDB] Table '$TABLE_NAME' already exists."
else
  echo "⚠️ [DynamoDB] Table '$TABLE_NAME' not found. Creating..."
  
  aws dynamodb create-table \
    --table-name "$TABLE_NAME" \
    --attribute-definitions AttributeName=LockID,AttributeType=S \
    --key-schema AttributeName=LockID,KeyType=HASH \
    --billing-mode PAY_PER_REQUEST \
    --region "$REGION"

  echo "   [DynamoDB] Waiting for table to be active..."
  aws dynamodb wait table-exists --table-name "$TABLE_NAME" --region "$REGION"
  
  echo "✅ [DynamoDB] Table created successfully."
fi

echo "----------------------------------------------------------------"
echo "Resources Ready."
echo "----------------------------------------------------------------"