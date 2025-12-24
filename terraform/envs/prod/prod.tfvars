# terraform.tfvars

project_name  = "iot"
owner         = "grp1-ce11"
region        = "us-east-1"
environment   = "prod"
instance_type = "t3.medium"


vpc_cidr = "10.0.0.0/16"

#public_subnet_cidr = "10.0.1.0/24"
public_subnet_cidrs = ["10.0.1.0/24", "10.0.2.0/24"]

# Provide your actual SSH keypair name here
key_name = "grp1-ec2-keypair"

# Number of simulator EC2 instances
simulator_count = 2

# CIDR block allowed to access EC2 services
allowed_cidr = "0.0.0.0/0"

# S3 bucket name for storing IoT certificates
# Explicitly set here instead of interpolating in variable default
#cert_s3_bucket  = "ce11-grp1-iot-sim-certs"

# S3 bucket for configurations
#config_s3_bucket  = "ce11-grp1-iot-sim-config"
#alert_email_recipients = ["shilpakangya2025@gmail.com"]

cert_files = {
  root_ca     = "AmazonRootCA1.pem"
  device_cert = "device-certificate.pem.crt"
  private_key = "private.pem.key"
}

create_buckets           = true
create_backend_resources = true

iot_topic      = "factory/plant1/line1"
s3_bucket_name = "prod-iot-telemetry-storage"

enable_cert_upload         = true
enable_grafana_smtp_secret = true
