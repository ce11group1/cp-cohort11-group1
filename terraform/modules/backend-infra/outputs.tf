# modules/backend-infra/outputs.tf

output "s3_bucket_name" {
  # Logic: If we created it, take ID from 'resource'. If not, take ID from 'data'.
  value = var.create_backend_resources ? aws_s3_bucket.terraform_state[0].id : data.aws_s3_bucket.existing_state[0].id
}

output "dynamodb_table_name" {
  value = var.create_backend_resources ? aws_dynamodb_table.terraform_locks[0].name : data.aws_dynamodb_table.existing_locks[0].name
}