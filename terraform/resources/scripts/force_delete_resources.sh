# 1. Delete ECS Service (The blocker)
aws ecs update-service --cluster grp1-ce11-dev-iot-cluster --service dev-iot-service --desired-count 0
aws ecs delete-service --cluster grp1-ce11-dev-iot-cluster --service dev-iot-service --force
echo "Waiting for service deletion..."
sleep 20

# 2. Delete Load Balancer (ALB)
ALB_ARN=$(aws elbv2 describe-load-balancers --names grp1-ce11-dev-iot-alb --query "LoadBalancers[0].LoadBalancerArn" --output text)
if [ "$ALB_ARN" != "None" ]; then aws elbv2 delete-load-balancer --load-balancer-arn "$ALB_ARN"; fi
sleep 15

# 3. Delete Target Groups
TG1=$(aws elbv2 describe-target-groups --names grp1-ce11-dev-iot-graf-tg --query "TargetGroups[0].TargetGroupArn" --output text)
if [ "$TG1" != "None" ]; then aws elbv2 delete-target-group --target-group-arn "$TG1"; fi

TG2=$(aws elbv2 describe-target-groups --names grp1-ce11-dev-iot-prom-tg --query "TargetGroups[0].TargetGroupArn" --output text)
if [ "$TG2" != "None" ]; then aws elbv2 delete-target-group --target-group-arn "$TG2"; fi

# 4. Delete IAM Roles (The "Already Exists" errors)
aws iam detach-role-policy --role-name dev-iot-execution-role --policy-arn arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy
aws iam delete-role --role-name dev-iot-execution-role

aws iam delete-role-policy --role-name dev-iot-task-role --policy-name dev-iot-task-policy
aws iam delete-role --role-name dev-iot-task-role

aws iam detach-role-policy --role-name iot-dev-cw-logger-role --policy-arn arn:aws:iam::255945442255:policy/iot-dev-cw-logger-policy
aws iam delete-role --role-name iot-dev-cw-logger-role

# 5. Delete IoT Policy
aws iot delete-policy --policy-name iot-sim-policy-dev

# 6. Delete CloudWatch Log Groups
aws logs delete-log-group --log-group-name /ecs/iot-simulator
aws logs delete-log-group --log-group-name /aws/iot/rules/dev

# 7. Delete ECR Repository (Force delete images too)
aws ecr delete-repository --repository-name grp1-ce11-dev-iot-simulator --force

# 8. Delete S3 Bucket (Force delete contents too)
aws s3 rb s3://dev-iot-telemetry-storage --force