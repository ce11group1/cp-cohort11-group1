# 1. Define Variables
REGION="us-east-1"
ALB_NAME="grp1-ce11-dev-iot-alb"
TG_GRAF="grp1-ce11-dev-iot-graf-tg"
TG_PROM="grp1-ce11-dev-iot-prom-tg"

echo "--- 🔍 CHECKING REGION: $REGION ---"

# 2. Find the Load Balancer ARN
ALB_ARN=$(aws elbv2 describe-load-balancers --names "$ALB_NAME" --region "$REGION" --query "LoadBalancers[0].LoadBalancerArn" --output text 2>/dev/null)

if [ "$ALB_ARN" == "None" ] || [ -z "$ALB_ARN" ]; then
  echo "⚠️  ALB '$ALB_NAME' NOT found. It might already be deleted."
else
  echo "✅ Found ALB: $ALB_ARN"
  
  # 3. DELETE LISTENERS (This unlocks the Target Groups)
  echo "   ✂️  Deleting Listeners..."
  LISTENER_ARNS=$(aws elbv2 describe-listeners --load-balancer-arn "$ALB_ARN" --region "$REGION" --query "Listeners[*].ListenerArn" --output text)
  
  if [ -z "$LISTENER_ARNS" ] || [ "$LISTENER_ARNS" == "None" ]; then
    echo "      No listeners found."
  else
    # Handle multiple listeners by converting spaces to newlines
    echo "$LISTENER_ARNS" | tr '\t' '\n' | while read ARN; do
       if [ ! -z "$ARN" ]; then
         echo "      🔥 Deleting: $ARN"
         aws elbv2 delete-listener --listener-arn "$ARN" --region "$REGION"
       fi
    done
  fi

  # 4. DELETE THE ALB
  echo "   🗑️  Deleting ALB..."
  aws elbv2 delete-load-balancer --load-balancer-arn "$ALB_ARN" --region "$REGION"
  echo "   ⏳ Waiting 15s for AWS to process..."
  sleep 15
fi

# 5. FORCE DELETE TARGET GROUPS
echo "--- 🧹 CLEANING TARGET GROUPS ---"

# Delete Grafana TG
TG_ARN_GRAF=$(aws elbv2 describe-target-groups --names "$TG_GRAF" --region "$REGION" --query "TargetGroups[0].TargetGroupArn" --output text 2>/dev/null)
if [ ! -z "$TG_ARN_GRAF" ] && [ "$TG_ARN_GRAF" != "None" ]; then
   echo "   🔥 Deleting Grafana TG: $TG_ARN_GRAF"
   aws elbv2 delete-target-group --target-group-arn "$TG_ARN_GRAF" --region "$REGION"
else
   echo "   ✅ Grafana TG already gone."
fi

# Delete Prometheus TG
TG_ARN_PROM=$(aws elbv2 describe-target-groups --names "$TG_PROM" --region "$REGION" --query "TargetGroups[0].TargetGroupArn" --output text 2>/dev/null)
if [ ! -z "$TG_ARN_PROM" ] && [ "$TG_ARN_PROM" != "None" ]; then
   echo "   🔥 Deleting Prometheus TG: $TG_ARN_PROM"
   aws elbv2 delete-target-group --target-group-arn "$TG_ARN_PROM" --region "$REGION"
else
   echo "   ✅ Prometheus TG already gone."
fi

echo "✅ DONE. Try re-running the pipeline now."