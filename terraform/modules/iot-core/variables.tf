variable "thing_name" {
  description = "Name of the IoT Thing"
  type        = string
}

variable "iot_topic" {
  description = "MQTT topic the device publishes to"
  type        = string
  # Change if your topic is different
  default     = "cet11/grp1/telemetry"
}

variable "create_certificate" {
  description = "Whether to create an IoT certificate and attach it to the Thing"
  type        = bool
  default     = true
}

# ---- IoT Rule → SNS integration ----

variable "enable_sns_action" {
  description = "Enable SNS action in IoT Topic Rule"
  type        = bool
  default     = false
}

variable "sns_topic_arn" {
  description = "SNS topic ARN to which IoT Rule will publish"
  type        = string
  default     = null
}

variable "sns_role_arn" {
  description = "IAM Role ARN that IoT Rule will assume to publish to SNS"
  type        = string
  default     = null
}
