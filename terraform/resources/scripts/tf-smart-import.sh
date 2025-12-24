#!/bin/bash
# Usage: ./tf-smart-import.sh <ENV> <AWS_ACCOUNT_ID>

ENV=$1
ACCOUNT_ID=$2

if [ -z "$ENV" ] || [ -z "$ACCOUNT_ID" ]; then
  echo "❌ Error: Usage ./tf-smart-import.sh <env> <account_id>"
  exit 1
fi

echo "--- 🛡️ STARTING COMPREHENSIVE SMART IMPORT ($ENV) ---"

# --- FUNCTION: IMPORT IF EXISTS ---
import_if_exists() {
  local TF_ADDR=$1
  local AWS_ID=$2
  
  # 1. Check if Terraform already has it
  if terraform state show "$TF_ADDR" > /dev/null 2>&1; then
    echo "✅ Already in state: $TF_ADDR"
  else
    # 2. Check if it actually exists in AWS (skip if empty)
    if [ -z "$AWS_ID" ] || [ "$AWS_ID" == "None" ]; then
        echo "⚪ Resource not found in AWS (Terraform will create): $TF_ADDR"
    else
        echo "📥 Importing existing resource: $AWS_ID"
        
        # 🟢 ADD THE -var-file FLAG HERE 🟢
        terraform import -var-file="${ENV}.tfvars" "$TF_ADDR" "$AWS_ID" || echo "⚠️ Import failed"
    fi
  fi
}

# ==========================================
# 1. IAM ROLES & POLICIES (Previous Fixes)
# ==========================================
EXEC_ROLE="${ENV}-iot-execution-role"
TASK_ROLE="${ENV}-iot-task-role"
IOT_POLICY="iot-sim-policy-${ENV}"
LOG_ROLE="iot-${ENV}-cw-logger-role"
LOG_POLICY_ARN="arn:aws:iam::${ACCOUNT_ID}:policy/iot-${ENV}-cw-logger-policy"
RULE_ROLE="iot-rule-${ENV}-s3-writer-role"
RULE_POLICY_ARN="arn:aws:iam::${ACCOUNT_ID}:policy/iot-rule-${ENV}-s3-write-policy"

import_if_exists "module.app.module.iot_ecs.aws_iam_role.execution_role" "$EXEC_ROLE"
import_if_exists "module.app.module.iot_ecs.aws_iam_role.task_role"      "$TASK_ROLE"
import_if_exists "module.app.module.iot.aws_iot_policy.sim_policy"        "$IOT_POLICY"
import_if_exists "module.app.module.iot_logging.aws_iam_policy.iot_logging_policy" "$LOG_POLICY_ARN"
import_if_exists "module.app.module.iot_logging.aws_iam_role.iot_logging_role"     "$LOG_ROLE"
import_if_exists "module.app.module.iot_rule.aws_iam_role.iot_rule_s3_role"     "$RULE_ROLE"
import_if_exists "module.app.module.iot_rule.aws_iam_policy.iot_rule_s3_policy" "$RULE_POLICY_ARN"


# ==========================================
# 2. INFRASTRUCTURE (New Fixes)
# ==========================================

# --- S3 BUCKET ---
BUCKET_NAME="${ENV}-iot-telemetry-storage"
import_if_exists "module.app.module.iot_storage.aws_s3_bucket.iot_data_bucket" "$BUCKET_NAME"

# --- ECR REPOSITORY ---
REPO_NAME="grp1-ce11-${ENV}-iot-simulator"
import_if_exists "module.app.module.ecr_simulator.aws_ecr_repository.main" "$REPO_NAME"

# --- CLOUDWATCH LOG GROUPS ---
# Note: Check if your main.tf uses specific names or defaults. 
# Based on your error log:
LOG_GROUP_ECS="/ecs/iot-simulator"
LOG_GROUP_IOT="/aws/iot/rules/${ENV}"

import_if_exists "module.app.module.iot_ecs.aws_cloudwatch_log_group.logs" "$LOG_GROUP_ECS"
import_if_exists "module.app.module.iot_logging.aws_cloudwatch_log_group.iot_rules_log_group" "$LOG_GROUP_IOT"


# ==========================================
# 3. NETWORKING (ALB & TARGET GROUPS)
# ==========================================
# These require ARNs, so we fetch them first using AWS CLI

echo "🔎 Fetching Network ARNs..."

# ALB
ALB_NAME="grp1-ce11-${ENV}-iot-alb"
ALB_ARN=$(aws elbv2 describe-load-balancers --names "$ALB_NAME" --query "LoadBalancers[0].LoadBalancerArn" --output text 2>/dev/null)
import_if_exists "module.app.module.shared_alb.aws_lb.main" "$ALB_ARN"

# Target Group: Grafana
TG_GRAF_NAME="grp1-ce11-${ENV}-iot-graf-tg"
TG_GRAF_ARN=$(aws elbv2 describe-target-groups --names "$TG_GRAF_NAME" --query "TargetGroups[0].TargetGroupArn" --output text 2>/dev/null)
import_if_exists "module.app.module.iot_ecs.aws_lb_target_group.grafana" "$TG_GRAF_ARN"

# Target Group: Prometheus
TG_PROM_NAME="grp1-ce11-${ENV}-iot-prom-tg"
TG_PROM_ARN=$(aws elbv2 describe-target-groups --names "$TG_PROM_NAME" --query "TargetGroups[0].TargetGroupArn" --output text 2>/dev/null)
import_if_exists "module.app.module.iot_ecs.aws_lb_target_group.prometheus" "$TG_PROM_ARN"

# ==========================================
# 4. S3 CONFIG & CERTS (Self-Healing Fix)
# ==========================================
# These names are taken directly from your error log
CONFIG_BUCKET="grp1-ce11-${ENV}-iot-config"
CERTS_BUCKET="grp1-ce11-${ENV}-iot-certs"

echo "🔎 Checking for existing Config/Certs buckets..."

# We use the [0] index because your error log showed: cert_bucket[0]
import_if_exists "module.app.module.s3_config.aws_s3_bucket.config_bucket[0]" "$CONFIG_BUCKET"
import_if_exists "module.app.module.s3_config.aws_s3_bucket.cert_bucket[0]" "$CERTS_BUCKET"

echo "--- 🏁 COMPREHENSIVE IMPORT COMPLETE ---"