# modules/iot_rule/main.tf

# The iot_rule Module (Core IoT & Rule Logic)
# This module handles the topic rule, its necessary IAM role for S3 write access, and the critical canned_acl fix.
# modules/iot_rule/main.tf

# IAM Role for the IoT Topic Rule to access S3 (Trust Policy)
resource "aws_iam_role" "iot_rule_s3_role" {
  name = "iot-rule-${var.environment}-s3-writer-role"
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

# IAM Policy to grant S3 write permissions (PutObject and PutObjectAcl)
resource "aws_iam_policy" "iot_rule_s3_policy" {
  name        = "iot-rule-${var.environment}-s3-write-policy"
  description = "Allows IoT Rule to write objects to the S3 bucket."
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action = [
        "s3:PutObject",
        "s3:PutObjectAcl" # Included for new bucket Object Owner Enforced compatibility
        #"s3:AbortMultipartUpload"
      ],
      Effect = "Allow",
      Resource = "${var.s3_bucket_arn}/*"
    }]
  })
}

# Attach Policy to the Rule Role
resource "aws_iam_role_policy_attachment" "iot_rule_s3_attach" {
  role       = aws_iam_role.iot_rule_s3_role.name
  policy_arn = aws_iam_policy.iot_rule_s3_policy.arn
}

# AWS IoT Topic Rule to S3 Action
resource "aws_iot_topic_rule" "s3_storage_rule" {
  name        = "SimulatorDataToS3Rule_${var.environment}"
  enabled     = true
  # SQL to select all data from the simulator topic root
  sql         = "SELECT * FROM '${var.iot_topic}/#'"
  sql_version = "2016-03-23"

  s3 {
    bucket_name = var.s3_bucket_name
    
    # CRITICAL: Unique S3 key using escaped substitution for Terraform
    key       = "$${topic()}/$${timestamp()}.json"

    # CRITICAL FIX: Ensures the S3 object is owned by the bucket owner
    #canned_acl = "bucket-owner-full-control"

    role_arn  = aws_iam_role.iot_rule_s3_role.arn
  }

  # Optional Error Action (republishes failure reason to MQTT topic)
  error_action {
    republish {
      topic    = "simulator/s3/errors"
      role_arn = aws_iam_role.iot_rule_s3_role.arn
    }
  }

  # error_action {
  #   cloudwatch_logs {
  #     log_group_name = "/aws/iot/rules/${var.environment}"
  #     role_arn       = aws_iam_role.iot_s3_role.arn
  #   }
  # }
}