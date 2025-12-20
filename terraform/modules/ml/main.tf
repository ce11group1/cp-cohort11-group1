# Allow S3 to send messages to SQS
resource "aws_sqs_queue_policy" "allow_s3" {
  queue_url = aws_sqs_queue.model_reload.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid: "AllowS3SendMessage"
      Effect: "Allow"
      Principal: { Service: "s3.amazonaws.com" }
      Action: "sqs:SendMessage"
      Resource: aws_sqs_queue.model_reload.arn
      Condition: {
        ArnEquals: {
          "aws:SourceArn": "arn:aws:s3:::${var.telemetry_bucket_name}"
        }
      }
    }]
  })
}

# Attach S3 notification to existing telemetry bucket for new models
resource "aws_s3_bucket_notification" "model_notifications" {
  bucket = var.telemetry_bucket_name

  queue {
    queue_arn     = aws_sqs_queue.model_reload.arn
    events        = ["s3:ObjectCreated:*"]
    filter_prefix = "ml/models/"
  }

  depends_on = [aws_sqs_queue_policy.allow_s3]
}

output "model_reload_queue_url" { value = aws_sqs_queue.model_reload.id }
output "model_reload_queue_arn" { value = aws_sqs_queue.model_reload.arn }
output "ml_scorer_task_role_arn" { value = aws_iam_role.ml_scorer_task_role.arn }
