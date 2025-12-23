#!/bin/bash

BUCKET_NAME=$1
REGION=${2:-us-east-1} # Default to us-east-1 if no region is passed

if [ -z "$BUCKET_NAME" ]; then
  echo "Usage: $0 <bucket-name> [region]"
  exit 1
fi

echo "Checking if bucket '$BUCKET_NAME' exists..."

# Check if bucket exists using head-bucket
# We redirect output to /dev/null because we only care about the exit code
if aws s3api head-bucket --bucket "$BUCKET_NAME" 2>/dev/null; then
  echo "✅ Bucket '$BUCKET_NAME' already exists."
else
  echo "⚠️ Bucket '$BUCKET_NAME' not found. Creating..."

  if [ "$REGION" == "us-east-1" ]; then
    # us-east-1 does not allow LocationConstraint
    aws s3api create-bucket --bucket "$BUCKET_NAME" --region "$REGION"
  else
    # Other regions require LocationConstraint
    aws s3api create-bucket \
      --bucket "$BUCKET_NAME" \
      --region "$REGION" \
      --create-bucket-configuration LocationConstraint="$REGION"
  fi

  if [ $? -eq 0 ]; then
    echo "✅ Bucket '$BUCKET_NAME' created successfully in $REGION."
  else
    echo "❌ Failed to create bucket."
    exit 1
  fi
fi