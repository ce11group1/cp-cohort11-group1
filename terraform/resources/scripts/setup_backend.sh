#!/bin/bash

# Configuration
BUCKET_NAME="grp1-ce11-iot-factory-state-bucket"
TABLE_NAME="terraform-locks"
REGION="us-east-1"

echo "----------------------------------------------------------------"
echo "Initializing Terraform Backend Infrastructure in $REGION"
echo "----------------------------------------------------------------"

# 1. Create S3 Bucket (if it doesn't exist)
if aws s3api head-bucket --bucket "$BUCKET_NAME" 2>/dev/null; then
    echo "✅ S3 Bucket '$BUCKET_NAME' already exists."
else
    echo "🚧 Creating S3 Bucket '$BUCKET_NAME'..."
    
    # AWS has a quirk: us-east-1 does NOT use LocationConstraint
    if [ "$REGION" == "us-east-1" ]; then
        aws s3api create-bucket \
            --bucket "$BUCKET_NAME" \
            --region "$REGION"
    else
        aws s3api create-bucket \
            --bucket "$BUCKET_NAME" \
            --region "$REGION" \
            --create-bucket-configuration LocationConstraint="$REGION"
    fi
    
    # Enable Versioning (Highly Recommended for State files)
    aws s3api put-bucket-versioning \
        --bucket "$BUCKET_NAME" \
        --versioning-configuration Status=Enabled
        
    echo "✅ S3 Bucket created and versioning enabled."
fi

# 2. Create DynamoDB Table (if it doesn't exist)
if aws dynamodb describe-table --table-name "$TABLE_NAME" --region "$REGION" >/dev/null 2>&1; then
    echo "✅ DynamoDB Table '$TABLE_NAME' already exists."
else
    echo "🚧 Creating DynamoDB Table '$TABLE_NAME'..."
    
    aws dynamodb create-table \
        --table-name "$TABLE_NAME" \
        --attribute-definitions AttributeName=LockID,AttributeType=S \
        --key-schema AttributeName=LockID,KeyType=HASH \
        --provisioned-throughput ReadCapacityUnits=5,WriteCapacityUnits=5 \
        --region "$REGION"

    echo "✅ DynamoDB Table created."
fi

echo "----------------------------------------------------------------"
echo "🎉 Backend setup complete! You can now run 'terraform init'."
echo "----------------------------------------------------------------"