# /main-app/main.tf

locals {
  # Logic: Just use the provided owner variable directly
  # Result: "{owner}-{env}-{project}"
  # Example: "shilpa-dev-iot-factory" OR "grp1-prod-iot-factory"
  resource_prefix = "${var.owner}-${var.environment}-${var.project_name}"

  common_tags = {
    Owner       = var.owner
    Environment = var.environment
    Project     = var.project_name
   }
}

################################################################################
# 1. BACKEND INFRASTRUCTURE
################################################################################
# module "backend_infra" {
#   source = "../backend-infra"

#   # IMPORTANT: Always keep this TRUE for the main project.
#   # Only set to false if you lost your state file but the bucket still exists.
#   create_backend_resources = true
  
#   # Names must be globally unique
#   bucket_name         = "${local.resource_prefix}-state-bucket"
#   dynamodb_table_name = "${local.resource_prefix}-locks"
#   tags                = local.common_tags
# }

################################################################################
# 2. APPLICATION MODULES
################################################################################

module "network" {
  source = "../network"

  name_prefix = local.resource_prefix
  tags        = local.common_tags
  vpc_cidr           = var.vpc_cidr
  # CHANGE: Match the new variable name inside the module
  public_subnet_cidrs = var.public_subnet_cidrs
  environment         = var.environment
  allowed_cidr        = var.allowed_cidr
}

module "iot" {
  source = "../iot"
  region      = var.region
  environment = var.environment
  iot_topic   = var.iot_topic
  tags        = local.common_tags
}

# IoT Logging Module
module "iot_logging" {
  source      = "../iot_logging"
  environment = var.environment
  region      = var.region
  log_level   = "DEBUG"
  tags        = local.common_tags
}

# IoT Storage Module (S3 Bucket)
module "iot_storage" {
  source           = "../iot_storage"
  environment      = var.environment
  region           = var.region
  iot_topic        = var.iot_topic
  s3_bucket_name   = var.s3_bucket_name
  tags             = local.common_tags
}

# IoT Rule Module
module "iot_rule" {
  source          = "../iot_rule"
  environment     = var.environment
  iot_topic       = var.iot_topic

  # Pass outputs from storage module as inputs
  s3_bucket_name  = module.iot_storage.bucket_name
  s3_bucket_arn   = module.iot_storage.bucket_arn
  
  # Ensure the logging module runs first, though not strictly required for inputs here
  depends_on = [module.iot_logging]
}

# Create the Shared Load Balancer
module "shared_alb" {
  source = "../shared-alb"

  name_prefix = local.resource_prefix
  tags        = local.common_tags
  vpc_id         = module.network.vpc_id     # Assuming you have a VPC module
  public_subnets = module.network.public_subnets
}

# S3 Config (Dashboards & Certs)
module "s3_config" {
  source = "../s3_config"

  name_prefix = local.resource_prefix
  tags        = local.common_tags
  region           = var.region
  environment      = var.environment
  create_buckets   = var.create_buckets

  # Compose bucket names dynamically
  config_s3_bucket = "${local.resource_prefix}-config" 
  cert_s3_bucket   = "${local.resource_prefix}-certs"

    # Add this line
  cert_files        = var.cert_files
}

# IoT Simulator (ECS Fargate)
module "iot_ecs" {
  source = "../iot-simulator-ecs"

  # Infrastructure wiring
  name_prefix = local.resource_prefix
  tags        = local.common_tags
  environment     = var.environment
  region          = var.region
  account_id      = data.aws_caller_identity.current.account_id
  cluster_id      = aws_ecs_cluster.main_cluster.id
  vpc_id          = module.network.vpc_id
  subnets         = module.network.public_subnets
  security_groups = [module.network.ecs_security_group_id]

# --- Connection to Shared ALB ---
  alb_listener_arn      = module.shared_alb.listener_arn
  alb_security_group_id = module.shared_alb.security_group_id

  # Configuration wiring (From S3 module)
  config_bucket   = module.s3_config.config_bucket_name
  cert_bucket     = module.s3_config.cert_bucket_name

  # App wiring (From IoT module)
  aws_iot_endpoint = module.iot.iot_endpoint
  iot_topic        = var.iot_topic
  simulator_count  = var.simulator_count
  iot_endpoint = module.iot.iot_endpoint
  repository_url = module.ecr_simulator.repository_url

  # DOCKER IMAGE
  # Update this URI after running 'docker push'
  #app_image_uri    = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.region}.amazonaws.com/iot-simulator:latest"
  # Image URI (Note: You must push the image manually after first apply)
  app_image_uri    = "${module.ecr_simulator.repository_url}:latest"
}

# Repository for the Python Simulator Code
module "ecr_simulator" {
  source = "../ecr"

  repository_name = "${local.resource_prefix}-simulator"
  environment     = var.environment
  tags = local.common_tags
}

resource "aws_ecs_cluster" "main_cluster" {
  name = "${local.resource_prefix}-cluster"
  tags = local.common_tags
}

data "aws_caller_identity" "current" {}

# Repository for Custom Grafana (Optional, only if you customize Grafana)
# module "ecr_grafana" {
#   source = "./modules/ecr"

#   repository_name = "iot-simulator-grafana"
#   environment     = var.environment
# }
