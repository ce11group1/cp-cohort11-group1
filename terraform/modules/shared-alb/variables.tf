# module/shared-alb/variables.tf

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

variable "vpc_id" {
  description = "The ID of the VPC where the security group and ALB will be created"
  type        = string
}

variable "public_subnets" { type = list(string) }
