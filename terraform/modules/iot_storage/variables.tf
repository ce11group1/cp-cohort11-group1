variable "environment" {
  type        = string
  description = "Environment name (dev/staging/prod)"
}

variable "iot_topic" {
  type        = string
  description = "Root MQTT topic prefix for IoT messages"
}

variable "tags" {
  type        = map(string)
  description = "Common tags"
}

variable "region" {
  type        = string
  description = "AWS region"
}

variable "s3_bucket_name" {
  description = "The globally unique name for the S3 bucket."
  type        = string
}