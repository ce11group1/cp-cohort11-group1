# modules/iot-simulator-ecs/outputs.tf

output "service_name" {
  description = "The name of the ECS service created"
  value       = aws_ecs_service.main.name
}

output "task_definition_arn" {
  description = "The ARN of the task definition"
  value       = aws_ecs_task_definition.main.arn
}

output "task_role_name" {
  value = aws_iam_role.task_role.name
}