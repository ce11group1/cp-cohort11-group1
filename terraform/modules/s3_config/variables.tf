# modules/s3_config/variables.tf

variable "tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default     = {}
}

# (Only for modules that need to name things, like Network/ALB/ECR)
variable "name_prefix" {
  description = "Standard naming prefix (owner-env-project)"
  type        = string
  default     = "" # Optional default to prevent errors if you miss it
}

variable "region" {
  type        = string
  description = "AWS region where S3 buckets and related resources will be created"
}

variable "environment" {
  type        = string
  description = "Deployment environment identifier (e.g., dev, staging, prod) used for naming and tagging resources"
}

variable "create_buckets" {
  type        = bool
  description = "Flag to control whether S3 buckets should be created by this module"
}

variable "config_s3_bucket" {
  type        = string
  description = "Name of the S3 bucket for storing configuration files"
}

variable "cert_s3_bucket" {
  type        = string
  description = "Name of the S3 bucket for storing IoT certificates"
}

variable "cert_files" {
  type        = map(string)
  description = "Map of certificate and key filenames to upload to S3"
}

# cert upload
variable "enable_cert_upload" {
  type    = bool
  default = true
}
