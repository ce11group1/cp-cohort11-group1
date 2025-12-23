#!/bin/bash
# Usage: ./cleanup.sh

echo "--- 🧨 STARTING NUCLEAR CLEANUP ---"

# --- 1. ECS SERVICE (CRITICAL FIX FOR IDEMPOTENT ERROR) ---
echo "1. Deleting ECS Service..."
CLUSTER="grp1-ce11-dev-iot-cluster"
SERVICE="dev-iot-service"

# Force update to 0 tasks to speed up draining
aws ecs update-service --cluster "$CLUSTER" --service "$SERVICE" --desired-count 0 2>/dev/null
aws ecs delete-service --cluster "$CLUSTER" --service "$SERVICE" --force 2>/dev/null

echo "   ⏳ Waiting for Service to fully disappear (This stops the 'Idempotent' error)..."
# This command pauses the script until the service is truly gone
aws ecs wait services-inactive --cluster "$CLUSTER" --services "$SERVICE" 2>/dev/null || echo "   Service already gone or wait timed out."


# --- 2. LOAD BALANCER & LISTENERS ---
echo "2. Deleting Load Balancer & Listeners..."
ALB_ARN=$(aws elbv2 describe-load-balancers --names grp1-ce11-dev-iot-alb --query "LoadBalancers[0].LoadBalancerArn" --output text 2>/dev/null)

if [ "$ALB_ARN" != "None" ] && [ ! -z "$ALB_ARN" ]; then 
  # Delete Listeners FIRST (Fixes 'ResourceInUse' error for Target Groups)
  LISTENER_ARNS=$(aws elbv2 describe-listeners --load-balancer-arn "$ALB_ARN" --query "Listeners[*].ListenerArn" --output text)
  for ARN in $LISTENER_ARNS; do
     if [ "$ARN" != "None" ]; then 
        echo "   Deleting Listener: $ARN"
        aws elbv2 delete-listener --listener-arn "$ARN"
     fi
  done
  
  # Then delete ALB
  aws elbv2 delete-load-balancer --load-balancer-arn "$ALB_ARN"
  
  echo "   ⏳ Waiting for ALB deletion..."
  aws elbv2 wait load-balancers-deleted --load-balancer-arns "$ALB_ARN" 2>/dev/null
fi


# --- 3. TARGET GROUPS ---
echo "3. Deleting Target Groups..."
TG1=$(aws elbv2 describe-target-groups --names grp1-ce11-dev-iot-graf-tg --query "TargetGroups[0].TargetGroupArn" --output text 2>/dev/null)
if [ "$TG1" != "None" ] && [ ! -z "$TG1" ]; then aws elbv2 delete-target-group --target-group-arn "$TG1"; fi

TG2=$(aws elbv2 describe-target-groups --names grp1-ce11-dev-iot-prom-tg --query "TargetGroups[0].TargetGroupArn" --output text 2>/dev/null)
if [ "$TG2" != "None" ] && [ ! -z "$TG2" ]; then aws elbv2 delete-target-group --target-group-arn "$TG2"; fi


# --- 4. IAM ROLES & POLICIES ---
echo "4. Cleaning up IAM Roles..."
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

# A) Execution Role
aws iam detach-role-policy --role-name dev-iot-execution-role --policy-arn arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy 2>/dev/null
aws iam delete-role --role-name dev-iot-execution-role 2>/dev/null

# B) Task Role
aws iam delete-role-policy --role-name dev-iot-task-role --policy-name dev-iot-task-policy 2>/dev/null
aws iam delete-role --role-name dev-iot-task-role 2>/dev/null

# C) IoT Logging Role
aws iam detach-role-policy --role-name iot-dev-cw-logger-role --policy-arn "arn:aws:iam::${ACCOUNT_ID}:policy/iot-dev-cw-logger-policy" 2>/dev/null
aws iam delete-role --role-name iot-dev-cw-logger-role 2>/dev/null

# D) IoT Rule S3 Role
aws iam detach-role-policy --role-name iot-rule-dev-s3-writer-role --policy-arn "arn:aws:iam::${ACCOUNT_ID}:policy/iot-rule-dev-s3-write-policy" 2>/dev/null
aws iam delete-role --role-name iot-rule-dev-s3-writer-role 2>/dev/null

echo "5. Deleting Custom IAM Policies..."
aws iam delete-policy --policy-arn "arn:aws:iam::${ACCOUNT_ID}:policy/iot-dev-cw-logger-policy" 2>/dev/null
aws iam delete-policy --policy-arn "arn:aws:iam::${ACCOUNT_ID}:policy/iot-rule-dev-s3-write-policy" 2>/dev/null


# --- 5. IOT CORE ---
echo "6. Cleaning up IoT Core..."
aws iot delete-topic-rule --rule-name "dev_iot_telemetry_rule" 2>/dev/null || aws iot delete-topic-rule --rule-name "dev-iot-telemetry-rule" 2>/dev/null
aws iot delete-policy --policy-name iot-sim-policy-dev 2>/dev/null


# --- 6. LOGS & STORAGE ---
echo "7. Deleting Log Groups..."
aws logs delete-log-group --log-group-name /ecs/iot-simulator 2>/dev/null
aws logs delete-log-group --log-group-name /aws/iot/rules/dev 2>/dev/null

echo "8. Deleting ECR..."
aws ecr delete-repository --repository-name grp1-ce11-dev-iot-simulator --force 2>/dev/null

echo "9. Deleting S3..."
aws s3 rb s3://dev-iot-telemetry-storage --force 2>/dev/null

echo "--- 🏁 CLEANUP COMPLETE ---"
echo ""
echo "⚠️  ======================================================="
echo "⚠️  CRITICAL NEXT STEP:"
echo "⚠️  You MUST now delete your 'terraform.tfstate' file."
echo "⚠️  - If Local: rm terraform/envs/dev/terraform.tfstate"
echo "⚠️  - If S3: Go to Console > S3 > dev-tfstate-bucket > Delete file"
echo "⚠️  ======================================================="