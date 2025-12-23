# modules/backend-infra/variables.tf

variable "bucket_name" {
  type        = string
  description = "The name of the S3 bucket for Terraform state"
}

variable "dynamodb_table_name" {
  type        = string
  description = "The name of the DynamoDB table for state locking"
}

variable "tags" {
  type    = map(string)
  default = {}
}

# --- THE TOGGLE SWITCH ---
variable "create_backend_resources" {
  type        = bool
  description = "Set to true to create resources. Set to false to read existing resources."
  default     = false # Default to 'false' so CI/CD (which uses the script) is safe.
}
