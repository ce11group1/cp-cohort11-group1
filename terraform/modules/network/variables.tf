# modules/network/variables.tf

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

variable "vpc_cidr" {
  type        = string
  description = "CIDR block for the VPC"
  default     = "10.0.0.0/16"
}

variable "environment" {
  type    = string
  default = "dev"
  description = "Deployment environment (e.g., dev, staging, prod)"
}

variable "allowed_cidr" {
  type        = string
  description = "CIDR block allowed to access EC2/ECS services (e.g., SSH, Grafana, Prometheus)"
}

# --- CHANGE THIS ---
variable "public_subnet_cidrs" {
  type        = list(string)
  description = "List of CIDR blocks for public subnets (e.g. ['10.0.1.0/24', '10.0.2.0/24'])"
  default     = ["10.0.1.0/24", "10.0.2.0/24"] # Default to 2 subnets
}
