output "log_group_name" {
  value = aws_cloudwatch_log_group.iot_rules_log_group.name
}

output "logging_role_arn" {
  description = "The ARN of the IAM role used for IoT logging."
  value       = aws_iam_role.iot_logging_role.arn
}