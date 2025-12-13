#!/bin/bash

# --- Configuration Variables ---
REGION="us-east-1" # <--- IMPORTANT: Change this to your correct AWS region
PROJECT_NAME="grp1-ce11-dev-iot"

# --- Resource Names from your Terraform output ---
STATE_BUCKET="${PROJECT_NAME}-state-bucket"
CONFIG_BUCKET="${PROJECT_NAME}-config"
CERTS_BUCKET="${PROJECT_NAME}-certs"
LOCK_TABLE="${PROJECT_NAME}-locks"
ALB_NAME="${PROJECT_NAME}-alb"
ECS_CLUSTER="${PROJECT_NAME}-cluster"
ECR_REPO="${PROJECT_NAME}-simulator"
EXECUTION_ROLE="dev-iot-execution-role"
TASK_ROLE="dev-iot-task-role"
LOG_GROUP="/ecs/iot-simulator"

echo "Starting cleanup of AWS resources for project: ${PROJECT_NAME} in region: ${REGION}"
echo "------------------------------------------------------"

# --- 1. Load Balancer and Target Groups Cleanup (Must be done before VPC/SG) ---

echo "1. Deleting Load Balancer and Target Groups..."

# Get ALB ARN and delete it
ALB_ARN=$(aws elbv2 describe-load-balancers --names "${ALB_NAME}" --region "${REGION}" --query 'LoadBalancers[0].LoadBalancerArn' --output text 2>/dev/null)
if [ "${ALB_ARN}" != "None" ] && [ ! -z "${ALB_ARN}" ]; then
    echo "  Deleting ALB: ${ALB_ARN}"
    aws elbv2 delete-load-balancer --load-balancer-arn "${ALB_ARN}" --region "${REGION}"
    aws elbv2 wait load-balancers-deleted --load-balancer-arns "${ALB_ARN}" --region "${REGION}" 2>/dev/null
else
    echo "  ALB ${ALB_NAME} not found or already deleted."
fi

# Target Groups (TGs will be automatically deleted if the ALB is gone, but we can confirm)
TG_NAMES=("grp1-ce11-dev-iot-graf-tg" "iot-sim-grafana-tg" "iot-sim-prometheus-tg")
for TG_NAME in "${TG_NAMES[@]}"; do
    TG_ARN=$(aws elbv2 describe-target-groups --names "${TG_NAME}" --region "${REGION}" --query 'TargetGroups[0].TargetGroupArn' --output text 2>/dev/null)
    if [ "${TG_ARN}" != "None" ] && [ ! -z "${TG_ARN}" ]; then
        echo "  Deleting Target Group: ${TG_ARN}"
        aws elbv2 delete-target-group --target-group-arn "${TG_ARN}" --region "${REGION}"
    else
        echo "  Target Group ${TG_NAME} not found."
    fi
done

# --- 2. ECS and ECR Cleanup ---

echo "2. Deleting ECS Cluster and ECR Repository..."

# Delete ECS Cluster (ECS services and tasks must be stopped/deleted first, but cluster deletion often handles this)
aws ecs delete-cluster --cluster "${ECS_CLUSTER}" --region "${REGION}" --no-cli-pager 2>/dev/null
echo "  ECS Cluster ${ECS_CLUSTER} delete command sent."

# Delete ECR Repository (Force delete to remove images)
aws ecr delete-repository --repository-name "${ECR_REPO}" --region "${REGION}" --force --no-cli-pager 2>/dev/null
echo "  ECR Repository ${ECR_REPO} delete command sent."

# --- 3. DynamoDB and CloudWatch Cleanup ---

echo "3. Deleting DynamoDB Table and Log Group..."

aws dynamodb delete-table --table-name "${LOCK_TABLE}" --region "${REGION}" --no-cli-pager 2>/dev/null
echo "  DynamoDB Table ${LOCK_TABLE} delete command sent."

aws logs delete-log-group --log-group-name "${LOG_GROUP}" --region "${REGION}" --no-cli-pager 2>/dev/null
echo "  CloudWatch Log Group ${LOG_GROUP} delete command sent."

# --- 4. IAM Roles Cleanup ---

echo "4. Deleting IAM Roles..."

# Function to remove attached policies and delete role
delete_iam_role() {
    local ROLE_NAME=$1
    echo "  Processing IAM Role: ${ROLE_NAME}"
    
    # Detach all managed policies
    for POLICY_ARN in $(aws iam list-attached-role-policies --role-name "${ROLE_NAME}" --query 'AttachedPolicies[].PolicyArn' --output text 2>/dev/null); do
        echo "    Detaching managed policy: ${POLICY_ARN}"
        aws iam detach-role-policy --role-name "${ROLE_NAME}" --policy-arn "${POLICY_ARN}"
    done

    # Delete all inline policies
    for POLICY_NAME in $(aws iam list-role-policies --role-name "${ROLE_NAME}" --query 'PolicyNames[]' --output text 2>/dev/null); do
        echo "    Deleting inline policy: ${POLICY_NAME}"
        aws iam delete-role-policy --role-name "${ROLE_NAME}" --policy-name "${POLICY_NAME}"
    done
    
    # Delete the role itself
    aws iam delete-role --role-name "${ROLE_NAME}" --no-cli-pager 2>/dev/null
    echo "    Role ${ROLE_NAME} delete command sent."
}

delete_iam_role "${EXECUTION_ROLE}"
delete_iam_role "${TASK_ROLE}"

# --- 5. S3 Buckets Cleanup (Must be emptied before deletion) ---

echo "5. Deleting S3 Buckets (Requires emptying)..."

# Function to empty and delete a bucket
delete_s3_bucket() {
    local BUCKET_NAME=$1
    if aws s3api head-bucket --bucket "${BUCKET_NAME}" 2>/dev/null; then
        echo "  Emptying bucket: ${BUCKET_NAME}"
        # Deletes all objects and their versions
        aws s3 rb s3://"${BUCKET_NAME}" --force --region "${REGION}"
        echo "  Bucket ${BUCKET_NAME} deleted."
    else
        echo "  Bucket ${BUCKET_NAME} not found."
    fi
}

delete_s3_bucket "${STATE_BUCKET}"
delete_s3_bucket "${CONFIG_BUCKET}"
delete_s3_bucket "${CERTS_BUCKET}"

# --- 6. VPC Cleanup (This is the most complex step) ---
# NOTE: This script assumes your VPC is tagged or named uniquely. 
# It's safest to delete this manually via the AWS console as per the previous suggestion.

# Since deleting the VPC via CLI is highly complex (needs to delete all subnets, route tables, etc., first)
# AND your last error was related to the VPC limit, it is highly recommended 
# that you delete the VPC created by your network module MANUALLY 
# in the AWS Console for safety and certainty.

echo "6. VPC Cleanup: PLEASE DELETE THE VPC MANUALLY."
echo "   Go to the VPC Dashboard in the AWS Console and delete the VPC associated with your subnets/resources."

echo "------------------------------------------------------"
echo "Cleanup script finished. Run 'terraform init' and 'terraform apply' after manual VPC cleanup."