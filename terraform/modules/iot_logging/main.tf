# 1. CloudWatch Log Group Resource
# AWS IoT Rules use the prefix /aws/iot/rules by convention
resource "aws_cloudwatch_log_group" "iot_rules_log_group" {
  # Name format requested by user: /aws/iot/rules/dev
  name              = "/aws/iot/rules/${var.environment}"
  retention_in_days = 7 #var.log_retention_days # Use a variable for controlled retention
  lifecycle {
    prevent_destroy       = false
    create_before_destroy = true
    ignore_changes        = [name]
  }
  # Note: The logs for AWS IoT CORE (the service itself) typically go to AWSIotLogsV2 or similar
  # This group is often used for the rule execution action, making it clear where errors originate.
}


# IAM Role for IoT to assume (Trust Policy)
resource "aws_iam_role" "iot_logging_role" {
  name = "iot-${var.environment}-cw-logger-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action = "sts:AssumeRole",
      Effect = "Allow",
      Principal = {
        Service = "iot.amazonaws.com"
      }
    }]
  })
}

# IAM Policy for CloudWatch write permissions
resource "aws_iam_policy" "iot_logging_policy" {
  name        = "iot-${var.environment}-cw-logger-policy"
  description = "Allows IoT to write logs to CloudWatch at the specified level."
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action = [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents",
        "logs:DescribeLogGroups"
      ],
      Effect   = "Allow",
      Resource = "*"
    }]
  })
}

# Attach Policy to Role
resource "aws_iam_role_policy_attachment" "iot_logging_attach" {
  role       = aws_iam_role.iot_logging_role.name
  policy_arn = aws_iam_policy.iot_logging_policy.arn
}

# Enable Global Logging (Set to DEBUG to capture all rule errors)
resource "aws_iot_logging_options" "global_logging" {
  default_log_level = var.log_level
  role_arn          = aws_iam_role.iot_logging_role.arn
}