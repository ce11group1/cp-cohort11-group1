resource "aws_cloudwatch_event_rule" "drift_schedule" {
  name                = "${var.environment}-ml-drift-schedule"
  schedule_expression = var.drift_schedule_expression
  tags                = var.tags
}

resource "aws_iam_role" "eventbridge_invoke_ecs" {
  name               = "${var.environment}-eventbridge-ecs-invoke"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = { Service = "events.amazonaws.com" }
      Action = "sts:AssumeRole"
    }]
  })
  tags = var.tags
}

resource "aws_iam_role_policy" "eventbridge_invoke_ecs" {
  role = aws_iam_role.eventbridge_invoke_ecs.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = ["ecs:RunTask"]
        Resource = [aws_ecs_task_definition.drift_check.arn]
      },
      {
        Effect = "Allow"
        Action = ["iam:PassRole"]
        Resource = ["*"]
      }
    ]
  })
}

resource "aws_cloudwatch_event_target" "drift_target" {
  rule      = aws_cloudwatch_event_rule.drift_schedule.name
  target_id = "ml-drift-check"
  arn       = var.ecs_cluster_arn
  role_arn  = aws_iam_role.eventbridge_invoke_ecs.arn

  ecs_target {
    task_definition_arn = aws_ecs_task_definition.drift_check.arn
    launch_type         = "FARGATE"
    network_configuration {
      subnets         = var.subnets
      security_groups = var.security_groups
      assign_public_ip = true
    }
  }
}
