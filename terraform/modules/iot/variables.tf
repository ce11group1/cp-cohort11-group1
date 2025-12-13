# modules/iot/variables.tf

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
  description = "AWS region where resources will be deployed (e.g., ap-southeast-1)"
}

variable "environment" {
  type        = string
  description = "Deployment environment identifier (e.g., dev, staging, prod)"
}

variable "iot_topic" {
  type        = string
  description = "IoT Core MQTT topic used by simulator instances for publishing messages"
}