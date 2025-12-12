# modules/backend-infra/variables.tf

variable "create_backend_resources" {
  description = "Set to true to create resources. Set to false to use existing ones."
  type        = bool
  default     = true
}

# Keep your existing variables...
variable "bucket_name" {}
variable "dynamodb_table_name" {}
variable "tags" { default = {} }