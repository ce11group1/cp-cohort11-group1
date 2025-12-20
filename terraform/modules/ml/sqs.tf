resource "aws_sqs_queue" "model_reload" {
  name = "${var.environment}-ml-model-reload-queue"

  visibility_timeout_seconds = 60
  message_retention_seconds  = 86400

  tags = merge(var.tags, { Name = "${var.environment}-ml-model-reload-queue" })
}

output "model_reload_queue_url" { value = aws_sqs_queue.model_reload.id }
output "model_reload_queue_arn" { value = aws_sqs_queue.model_reload.arn }
