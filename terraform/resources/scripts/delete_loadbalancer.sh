# 1. Copy the ARN directly from your error log
ALB_ARN="arn:aws:elasticloadbalancing:us-east-1:***:loadbalancer/app/grp1-ce11-dev-iot-alb/4c0929207073b9e6"

# 2. Force delete the broken ALB
echo "🗑️ Deleting broken Load Balancer..."
aws elbv2 delete-load-balancer --load-balancer-arn "$ALB_ARN" --region us-east-1

echo "✅ ALB deleted. Running refresh..."

# 3. Tell Terraform the ALB is gone
# (Run this inside your terraform/envs/dev folder)
#cd terraform/envs/dev
#terraform refresh -var-file="dev.tfvars"