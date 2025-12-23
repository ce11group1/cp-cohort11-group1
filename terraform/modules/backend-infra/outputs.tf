# modules/backend-infra/outputs.tf

output "bucket_arn" {
  description = "The ARN of the state bucket"
  value       = var.create_backend_resources ? aws_s3_bucket.terraform_state[0].arn : data.aws_s3_bucket.existing_state[0].arn
}

output "table_arn" {
  description = "The ARN of the lock table"
  value       = var.create_backend_resources ? aws_dynamodb_table.terraform_locks[0].arn : data.aws_dynamodb_table.existing_locks[0].arn
}

output "bucket_id" {
  value = var.create_backend_resources ? aws_s3_bucket.terraform_state[0].id : data.aws_s3_bucket.existing_state[0].id
}