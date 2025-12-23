echo "--- 🗑️ DELETING STUCK ECS SERVICE ---"

# 1. Define Variables
CLUSTER_NAME="grp1-ce11-dev-iot-cluster"  # Verify this is your actual cluster name
SERVICE_NAME="dev-iot-service"
REGION="us-east-1"

# 2. Force Delete the Service
echo "🗑️ Deleting stuck service: $SERVICE_NAME..."
aws ecs delete-service \
    --cluster "$CLUSTER_NAME" \
    --service "$SERVICE_NAME" \
    --force \
    --region "$REGION"

echo "✅ Service deleted. You can re-run the pipeline now."