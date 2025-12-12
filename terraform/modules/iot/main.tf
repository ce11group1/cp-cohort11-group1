# modules/iot/main.tf

############################################
# 1. IoT Endpoint (Data-ATS)
############################################

data "aws_iot_endpoint" "iot" {
  endpoint_type = "iot:Data-ATS"
}


############################################
# 2. IoT Thing
############################################

resource "aws_iot_thing" "simulator" {
  name = "${var.environment}-iot-simulator"
  attributes = {
    Owner = var.tags["Owner"] # Pass owner tag to IoT attribute
  }
}

############################################
# 3. IoT Policy (Allows Publish/Subscribe)
############################################

resource "aws_iot_policy" "sim_policy" {
  name   = "iot-sim-policy-${var.environment}"
  policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "iot:Connect",
          "iot:Publish",
          "iot:Subscribe",
          "iot:Receive"
        ]
        # Resource = [
        #   "arn:aws:iot:${var.region}:*:client/*",
        #   "arn:aws:iot:${var.region}:*:topic/${var.iot_topic}/*",
        #   "arn:aws:iot:${var.region}:*:topicfilter/${var.iot_topic}/*"
        # ]
        Resource = "*"
      }
    ]
  })
}


############################################
# 4. IoT Certificate
############################################

resource "aws_iot_certificate" "sim_cert" {
  active = true
}

############################################
# 5. Attach Policy → Certificate
############################################

resource "aws_iot_policy_attachment" "attach" {
  policy = aws_iot_policy.sim_policy.name
  target = aws_iot_certificate.sim_cert.arn
}

############################################
# 6. Attach Certificate → Thing
############################################

resource "aws_iot_thing_principal_attachment" "attach_cert" {
  thing     = aws_iot_thing.simulator.name
  principal = aws_iot_certificate.sim_cert.arn
}

# # ==============================================================================
# # 1. S3 BUCKET STORAGE
# # ==============================================================================

# # Helper data source to get your Account ID (ensures bucket name is unique)
# #data "aws_caller_identity" "current" {}

# resource "aws_s3_bucket" "telemetry_bucket" {
#   # Naming convention: env-app-purpose-accountID
#   # bucket        = "${var.environment}-iot-telemetry-storage-${data.aws_caller_identity.current.account_id}"
#   bucket        = "${var.environment}-iot-telemetry-storage"
#   force_destroy = true # Allows deleting bucket even if it contains files (for dev/capstone)
  
#   tags = merge(var.tags, {
#     Name = "${var.environment}-iot-telemetry"
#   })
# }

# # (Optional) Block public access to keep data secure
# # resource "aws_s3_bucket_public_access_block" "telemetry_bucket_block" {
# #   bucket = aws_s3_bucket.telemetry_bucket.id

# #   block_public_acls       = true
# #   block_public_policy     = true
# #   ignore_public_acls      = true
# #   restrict_public_buckets = true
# # }

# # ==============================================================================
# # 2. IAM ROLE (Allows IoT Core -> S3)
# # ==============================================================================

# resource "aws_iam_role" "iot_s3_role" {
#   name = "${var.environment}-iot-to-s3-role"

#   assume_role_policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = [{
#       Action = "sts:AssumeRole"
#       Effect = "Allow"
#       Principal = { Service = "iot.amazonaws.com" }
#     }]
#   })
# }

# resource "aws_iam_role_policy" "iot_s3_policy" {
#   name = "${var.environment}-iot-s3-policy"
#   role = aws_iam_role.iot_s3_role.id

#   policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = [{
#       Effect = "Allow"
#         Action = [
#           "s3:PutObject",
#           "s3:PutObjectAcl"
#           "s3:AbortMultipartUpload"
#         ],
#       # Allow writing to any file (*) inside the specific bucket
#       Resource = "${aws_s3_bucket.telemetry_bucket.arn}/*"
#     }]
#   })
# }

# # ==============================================================================
# # 3. IOT TOPIC RULE (The "Router")
# # ==============================================================================

# resource "aws_iot_topic_rule" "s3_save" {
#   name        = "iot_s3_storage_rule_${var.environment}"
#   description = "Route all telemetry data to S3 bucket"
#   enabled     = true
  
#   # SQL: Select ALL data (*) from the topic and any subtopic (/#)
#   sql         = "SELECT * FROM '${var.iot_topic}/#'"
#   sql_version = "2016-03-23"

#   s3 {
#     bucket_name = aws_s3_bucket.telemetry_bucket.bucket
    
#     # Organize files by Topic structure and Timestamp
#     # Example path: factory/plant1/line1/M001/1698765432.json
#     key         = "$${topic()}/$${timestamp()}.json"   
#     role_arn    = aws_iam_role.iot_s3_role.arn
#   }
# }