variable "region" {
  type        = string
  default     = "us-east-1"
  description = "AWS region to deploy resources"
}

variable "project_name" {
  description = "Project identifier"
  type        = string
  default     = "iot-factory"
}

variable "owner" {
  description = "Name of the owner (e.g., 'grp1' for prod or 'shilpa' for dev)"
  type        = string
}

variable "environment" {
  type        = string
  default     = "dev"
  description = "Deployment environment (e.g., dev, staging, prod)"
}

# Network

variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  type        = list(string)
  description = "List of public subnet CIDRs"
  default     = ["10.0.1.0/24", "10.0.2.0/24"] # Default to 2 subnets
}

variable "allowed_cidr" {
  type = string
  #default     = "0.0.0.0/0"
  description = "CIDR block allowed to access EC2 services (e.g., SSH, Grafana, Prometheus)"
}

# Compute
variable "instance_type" {
  type        = string
  default     = "t3.medium"
  description = "EC2 instance type for simulator host"
}

variable "simulator_count" {
  type        = number
  default     = 2
  description = "Number of simulator EC2 instances to launch"
}

variable "key_name" {
  type        = string
  description = "SSH keypair name for EC2 instance access"
  default     = "grp1-ec2-keypair.pem"
}

# IoT and Data

variable "iot_topic" {
  type        = string
  default     = "factory/plant1/line1"
  description = "MQTT topic for simulator publishing"
}

variable "s3_bucket_name" {
  type        = string
  description = "Unique name for the telemetry bucket"
}

variable "cert_files" {
  type        = map(string)
  description = "Map of certificate and key filenames to upload to S3"
  default = {
    root_ca     = "AmazonRootCA1.pem"
    device_cert = "device-certificate.pem.crt"
    private_key = "private.pem.key"
  }
}

# cert upload
variable "enable_cert_upload" {
  type    = bool
  default = true
}

# grafana smtp secret
variable "enable_grafana_smtp_secret" {
  type    = bool
  default = true
}

# Switches
variable "create_buckets" {
  type    = bool
  default = true
}

variable "create_backend_resources" {
  type    = bool
  default = true
}

variable "iot_cert_files" {
  type = object({
    root_ca     = string
    device_cert = string
    private_key = string
  })
}


# variable "config_s3_bucket" {
#   type        = string
#   description = "S3 bucket name for storing Prometheus/Grafana configs"
#   default     = "ce11-grp1-iot-sim-config"
# }

# variable "cert_s3_bucket" {
#   type        = string
#   description = "S3 bucket name for storing IoT certificates"
#   default     = "ce11-grp1-iot-sim-certs"
# }

# variable "alert_email_recipients" {
#   type        = list(string)
#   description = "List of email addresses to receive alerts"
#   default     = ["shilparg_2000@yahoo.com"]
# }





