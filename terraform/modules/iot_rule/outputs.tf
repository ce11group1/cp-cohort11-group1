output "iot_s3_role_arn" {
  value = aws_iam_role.iot_rule_s3_role.arn
}

output "iot_topic_rule_name" {
  value = aws_iot_topic_rule.s3_storage_rule.name
}