############################################
# 1. S3 BUCKET FOR TELEMETRY STORAGE
############################################

resource "aws_s3_bucket" "iot_data_bucket" {
  bucket        = var.s3_bucket_name
  force_destroy = true

  tags = merge(var.tags, {
    Name = "${var.environment}-iot-telemetry"
  })
}

# Block Public Access settings (All TRUE, as per best practice)
resource "aws_s3_bucket_public_access_block" "block_public_access" {
  bucket = aws_s3_bucket.iot_data_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# 1. Get current account ID (required for the policy condition)
data "aws_caller_identity" "current" {}

# 2. Attach a policy to the bucket allowing IoT Core to write
resource "aws_s3_bucket_policy" "allow_iot_writes" {
  bucket = aws_s3_bucket.iot_data_bucket.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AllowIoTWrite"
        Effect    = "Allow"
        Principal = { Service = "iot.amazonaws.com" }
        Action    = "s3:PutObject"
        Resource  = "${aws_s3_bucket.iot_data_bucket.arn}/*"
        Condition = {
          StringEquals = {
            "aws:SourceAccount" = data.aws_caller_identity.current.account_id
          }
        }
      }
    ]
  })
}

# Output the bucket details for the rule module to use
# output "bucket_name" {
#   description = "The name of the S3 bucket."
#   value       = aws_s3_bucket.iot_data_bucket.id
# }

# output "bucket_arn" {
#   description = "The ARN of the S3 bucket."
#   value       = aws_s3_bucket.iot_data_bucket.arn
# }