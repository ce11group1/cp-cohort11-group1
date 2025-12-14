# modules/iot_rule/variables.tf

variable "environment" {
  description = "Environment tag for resource naming."
  type        = string
}

variable "s3_bucket_name" {
  description = "The name of the S3 bucket to write to (from iot_storage module)."
  type        = string
}

variable "s3_bucket_arn" {
  description = "The ARN of the S3 bucket to use in IAM policies (from iot_storage module)."
  type        = string
}

variable "iot_topic" {
  description = "The root of the MQTT topic to subscribe to (e.g., factory/plant1/line1)."
  type        = string
}