# env/dev/main.tf

locals {
  common_tags = {
    Owner       = var.owner
    Environment = var.environment
    Project     = var.project_name
  }
}

# =========================================================================
# 1. BACKEND INFRA (State Bucket & Lock Table)
#    This creates the bucket defined in your backend.tf
# =========================================================================
module "backend_infra" {
  source = "../../modules/backend-infra"

  create_backend_resources = var.create_backend_resources
  bucket_name              = "grp1-ce11-dev-iot-state-bucket" # Must match backend.tf
  dynamodb_table_name      = "grp1-ce11-dev-iot-locks"        # Must match backend.tf
  tags                     = local.common_tags
}

# =========================================================================
# 2. MAIN APPLICATION (The "Facade" Module)
#    This module internally orchestrates Network, IoT, ECS, S3, and Rules.
# =========================================================================

module "app" {
  source = "../../modules/main-app"

  # Pass variables from tfvars to the module
  owner        = var.owner
  environment  = var.environment
  project_name = var.project_name
  region       = var.region

  # Network
  vpc_cidr            = var.vpc_cidr
  public_subnet_cidrs = var.public_subnet_cidrs
  allowed_cidr        = var.allowed_cidr

  # App Config
  instance_type   = var.instance_type
  simulator_count = var.simulator_count
  key_name        = var.key_name

  # IoT & Storage
  # We pass the bucket name here, and the app module creates it internally.
  s3_bucket_name = var.s3_bucket_name
  iot_topic      = var.iot_topic
  cert_files     = var.cert_files
  create_buckets = var.create_buckets

  iot_cert_files = var.iot_cert_files
}
