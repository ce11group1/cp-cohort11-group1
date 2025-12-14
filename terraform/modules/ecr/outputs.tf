# modules/ecr/output.tf

output "repository_url" {
  value       = aws_ecr_repository.main.repository_url
  description = "The URL of the repository (used in docker push/pull)"
}

output "repository_arn" {
  value       = aws_ecr_repository.main.arn
  description = "The ARN of the repository (used for IAM permissions)"
}

output "registry_id" {
  value       = aws_ecr_repository.main.registry_id
  description = "The registry ID where the repository was created"
}