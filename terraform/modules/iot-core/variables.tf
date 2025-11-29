variable "thing_name" {
  description = "Name of the IoT Thing"
  type        = string
  # Default so you always get this Thing unless you override
  default     = "ce11-grp1-sensor-thing"
}

variable "iot_topic" {
  description = "MQTT topic the device publishes to"
  type        = string
  # Adjust if your topic is different
  default     = "cet11/grp1/telemetry"
}

variable "create_certificate" {
  description = "Whether to create an IoT certificate and attach it to the Thing"
  type        = bool
  default     = true
}

# ---------- Optional: IoT Rule → SNS action ----------

variable "enable_sns_action" {
  description = "Enable SNS action in IoT Topic Rule"
  type        = bool
  default     = false
}

variable "sns_topic_arn" {
  description = "SNS topic ARN to which IoT Rule will publish (required if enable_sns_action = true)"
  type        = string
  default     = null
}

variable "sns_role_arn" {
  description = "IAM Role ARN that IoT Rule will assume to publish to SNS (required if enable_sns_action = true)"
  type        = string
  default     = null
}
