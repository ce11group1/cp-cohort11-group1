locals {
  common_env = [
    { name = "AWS_REGION", value = "us-east-1" },
    { name = "S3_BUCKET", value = var.telemetry_bucket_name },
    { name = "TELEMETRY_PREFIX", value = var.telemetry_prefix },
    { name = "FEATURES", value = "temperature,humidity" }
  ]
}

resource "aws_ecs_task_definition" "drift_check" {
  family                   = "${var.environment}-ml-drift-check"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "512"
  memory                   = "1024"
  execution_role_arn        = aws_iam_role.ml_jobs_task_role.arn
  task_role_arn             = aws_iam_role.ml_jobs_task_role.arn

  container_definitions = jsonencode([
    {
      name  = "drift-check"
      image = var.ml_jobs_image
      essential = true
      command = ["python", "/app/drift_check.py"]
      environment = concat(local.common_env, [
        { name = "WINDOW_MINUTES", value = "60" },
        { name = "PSI_THRESHOLD", value = "0.2" },
        { name = "KS_P_THRESHOLD", value = "0.05" },
        { name = "TRIGGER_RETRAIN", value = "true" },
        { name = "ECS_CLUSTER", value = var.ecs_cluster_arn },
        { name = "RETRAIN_TASK_DEF", value = "${var.environment}-ml-retrain" },
        { name = "SUBNETS", value = join(",", var.subnets) },
        { name = "SECURITY_GROUPS", value = join(",", var.security_groups) },
        { name = "ASSIGN_PUBLIC_IP", value = "true" }
      ])
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = "/ecs/${var.environment}/ml"
          awslogs-region        = "us-east-1"
          awslogs-stream-prefix = "drift"
        }
      }
    }
  ])
}

resource "aws_ecs_task_definition" "retrain" {
  family                   = "${var.environment}-ml-retrain"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "1024"
  memory                   = "2048"
  execution_role_arn        = aws_iam_role.ml_jobs_task_role.arn
  task_role_arn             = aws_iam_role.ml_jobs_task_role.arn

  container_definitions = jsonencode([
    {
      name  = "retrain"
      image = var.ml_jobs_image
      essential = true
      command = ["python", "/app/train.py"]
      environment = concat(local.common_env, [
        { name = "WINDOW_MINUTES", value = "240" }
      ])
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = "/ecs/${var.environment}/ml"
          awslogs-region        = "us-east-1"
          awslogs-stream-prefix = "train"
        }
      }
    }
  ])
}

resource "aws_cloudwatch_log_group" "ml" {
  name              = "/ecs/${var.environment}/ml"
  retention_in_days = 7
  tags              = var.tags
}

output "drift_task_definition_arn" { value = aws_ecs_task_definition.drift_check.arn }
output "retrain_task_definition_arn" { value = aws_ecs_task_definition.retrain.arn }
