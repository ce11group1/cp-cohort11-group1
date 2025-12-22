#!/bin/bash
# Usage: ./tf-smart-import.sh <ENV> <AWS_ACCOUNT_ID>
# Example: ./tf-smart-import.sh dev 123456789012

ENV=$1
ACCOUNT_ID=$2

if [ -z "$ENV" ] || [ -z "$ACCOUNT_ID" ]; then
  echo "❌ Error: Usage ./tf-smart-import.sh <env> <account_id>"
  exit 1
fi

echo "--- 🛡️ STARTING SMART IMPORT FOR ENV: $ENV ---"

# --- 1. DEFINE FUNCTION ---
# Imports a resource if it exists in AWS but is missing from Terraform State
import_if_exists() {
  local TF_ADDR=$1
  local AWS_ID=$2
  
  # Check if Terraform already knows about it
  if terraform state show "$TF_ADDR" > /dev/null 2>&1; then
    echo "✅ Already in state: $TF_ADDR"
  else
    echo "📥 Attempting import for $AWS_ID..."
    # Try import; if it fails (doesn't exist), echo a warning but don't crash script
    terraform import "$TF_ADDR" "$AWS_ID" || echo "⚠️ Import failed or resource not found (Terraform will create it)."
  fi
}

# --- 2. DEFINE RESOURCE NAMES (Must match Terraform naming convention) ---

# ECS Roles
EXEC_ROLE="${ENV}-iot-execution-role"
TASK_ROLE="${ENV}-iot-task-role"

# IoT Policy
IOT_POLICY="iot-sim-policy-${ENV}"

# Logging Role & Policy
LOG_ROLE="iot-${ENV}-cw-logger-role"
LOG_POLICY_ARN="arn:aws:iam::${ACCOUNT_ID}:policy/iot-${ENV}-cw-logger-policy"

# --- NEW: IoT Rule S3 Role & Policy (Added to fix your error) ---
RULE_ROLE="iot-rule-${ENV}-s3-writer-role"
RULE_POLICY_ARN="arn:aws:iam::${ACCOUNT_ID}:policy/iot-rule-${ENV}-s3-write-policy"


# --- 3. EXECUTE IMPORTS ---

# ECS Roles
import_if_exists "module.app.module.iot_ecs.aws_iam_role.execution_role" "$EXEC_ROLE"
import_if_exists "module.app.module.iot_ecs.aws_iam_role.task_role"      "$TASK_ROLE"

# IoT Policy
import_if_exists "module.app.module.iot.aws_iot_policy.sim_policy"        "$IOT_POLICY"

# Logging Roles & Policies
import_if_exists "module.app.module.iot_logging.aws_iam_policy.iot_logging_policy" "$LOG_POLICY_ARN"
import_if_exists "module.app.module.iot_logging.aws_iam_role.iot_logging_role"     "$LOG_ROLE"

# --- NEW: IoT Rule S3 Role & Policy ---
import_if_exists "module.app.module.iot_rule.aws_iam_role.iot_rule_s3_role"     "$RULE_ROLE"
import_if_exists "module.app.module.iot_rule.aws_iam_policy.iot_rule_s3_policy" "$RULE_POLICY_ARN"

echo "--- 🛡️ SMART IMPORT COMPLETE ---"