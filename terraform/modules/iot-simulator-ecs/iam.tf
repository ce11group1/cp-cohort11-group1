# modules/iot-simulator-ecs/iam.tf

# =========================================================
# 1. EXECUTION ROLE (Used by AWS to start your containers)
#    - Pulls images from ECR
#    - Fetches Secrets for Environment Variables
# =========================================================
resource "aws_iam_role" "execution_role" {
  name = "${var.environment}-iot-execution-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{ Action = "sts:AssumeRole", Effect = "Allow", Principal = { Service = "ecs-tasks.amazonaws.com" } }]
  })
  tags = merge(var.tags, { Name = "${var.environment}-iot-execution-role" })
}

resource "aws_iam_role_policy_attachment" "execution_policy" {
  role       = aws_iam_role.execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# --- CRITICAL FIX: Give Execution Role access to Secrets ---
resource "aws_iam_role_policy" "execution_secrets_policy" {
  name = "iot-sim-execution-secrets"
  role = aws_iam_role.execution_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow",
        Action = ["secretsmanager:GetSecretValue"],
        #Resource = ["arn:aws:secretsmanager:${var.region}:${var.account_id}:secret:grafana/smtp*"]
        # Use the DATA SOURCE ARN here too
        Resource = [data.aws_secretsmanager_secret.grafana_smtp.arn]
      }
    ]
  })
}

# =========================================================
# 2. TASK ROLE (Used by your Containers while running)
#    - Init Container uses this to download S3 files
# =========================================================
resource "aws_iam_role" "task_role" {
  name = "${var.environment}-iot-task-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{ Action = "sts:AssumeRole", Effect = "Allow", Principal = { Service = "ecs-tasks.amazonaws.com" } }]
  })
  tags = merge(var.tags, { Name = "${var.environment}-iot-task-role" })
}

# --- CRITICAL: Give Task Role access to S3 ---
resource "aws_iam_role_policy" "task_permissions" {
  name = "iot-sim-task-policy"
  role = aws_iam_role.task_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow",
        Action = ["s3:GetObject", "s3:ListBucket"],
        Resource = [
          "arn:aws:s3:::${var.config_bucket}", "arn:aws:s3:::${var.config_bucket}/*",
          "arn:aws:s3:::${var.cert_bucket}",   "arn:aws:s3:::${var.cert_bucket}/*"
        ]
      }
    ]
  })
}

# Custom Policy to replace user-data S3/Secrets logic
# resource "aws_iam_role_policy" "task_permissions" {
#   name = "iot-sim-custom-policy"
#   role = aws_iam_role.task_role.id
#   policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = [
#       {
#         Effect = "Allow",
#         Action = ["s3:GetObject", "s3:ListBucket"],
#         Resource = [
#           "arn:aws:s3:::${var.config_bucket}", "arn:aws:s3:::${var.config_bucket}/*",
#           "arn:aws:s3:::${var.cert_bucket}",   "arn:aws:s3:::${var.cert_bucket}/*"
#         ]
#       },
#       {
#         Effect = "Allow",
#         Action = ["secretsmanager:GetSecretValue"],
#         Resource = ["arn:aws:secretsmanager:${var.region}:${var.account_id}:secret:grafana/smtp*"]
#       }
#     ]
#   })
# }