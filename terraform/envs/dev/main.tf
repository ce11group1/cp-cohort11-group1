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

  enable_cert_upload         = var.enable_cert_upload
  enable_grafana_smtp_secret = var.enable_grafana_smtp_secret
}

module "ml" {
  source = "../../modules/ml"

  environment = var.environment
  tags        = local.common_tags

  telemetry_bucket_name = module.iot_storage.s3_bucket_name

  ecs_cluster_arn   = module.iot_simulator_ecs.ecs_cluster_arn
  subnets           = module.network.public_subnets
  security_groups   = [module.security.ecs_sg_id]

  ml_scorer_image = var.ml_scorer_image
  ml_jobs_image   = var.ml_jobs_image

  telemetry_prefix = "telemetry/" # change if your IoT rule uses another prefix
  drift_schedule_expression = "rate(15 minutes)"
}
