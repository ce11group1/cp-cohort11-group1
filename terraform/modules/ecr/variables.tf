# modules/ecr/variables.tf

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

variable "repository_name" {
  description = "The name of the ECR repository"
  type        = string
  default     = "iot-simulator"
}

variable "environment" {
  type        = string
  description = "The deployment environment (e.g., dev, prod)"
}

variable "image_mutability" {
  type        = string
  default     = "MUTABLE" # 'MUTABLE' allows overwriting tags (good for dev). Use 'IMMUTABLE' for prod.
  description = "The tag mutability setting for the repository"
}