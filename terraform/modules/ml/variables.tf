variable "environment" { type = string }
variable "tags" { type = map(string) }

variable "telemetry_bucket_name" { type = string }

variable "ecs_cluster_arn" { type = string }
variable "subnets" { type = list(string) }
variable "security_groups" { type = list(string) }

# ECR images (you will build/push)
variable "ml_scorer_image" { type = string }
variable "ml_jobs_image" { type = string }

# Telemetry prefix used by your IoT rule (adjust to match your current layout)
variable "telemetry_prefix" {
  type    = string
  default = "telemetry/"
}

# Schedule
variable "drift_schedule_expression" {
  type    = string
  default = "rate(15 minutes)"
}
