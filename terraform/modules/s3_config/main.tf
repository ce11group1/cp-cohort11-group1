# modules/s3_config/main.tf

# 1. Bucket Resources
resource "aws_s3_bucket" "config_bucket" {
  count         = var.create_buckets ? 1 : 0
  bucket        = var.config_s3_bucket
  force_destroy = var.environment != "prod" # Safer: Destroy only if NOT prod
  tags          = merge(var.tags, { Name = var.config_s3_bucket })
}

resource "aws_s3_bucket" "cert_bucket" {
  count         = var.create_buckets ? 1 : 0
  bucket        = var.cert_s3_bucket
  force_destroy = var.environment != "prod"
  tags          = merge(var.tags, { Name = var.cert_s3_bucket })
}

# 2. Data Sources (for when buckets already exist)
data "aws_s3_bucket" "config_bucket" {
  count  = var.create_buckets ? 0 : 1
  bucket = var.config_s3_bucket
}

data "aws_s3_bucket" "cert_bucket" {
  count  = var.create_buckets ? 0 : 1
  bucket = var.cert_s3_bucket
}

locals {
  # Resolve bucket IDs dynamically
  config_bucket_id = var.create_buckets ? aws_s3_bucket.config_bucket[0].id : data.aws_s3_bucket.config_bucket[0].id
  cert_bucket_id   = var.create_buckets ? aws_s3_bucket.cert_bucket[0].id : data.aws_s3_bucket.cert_bucket[0].id

  # Path to your resources folder (Up 2 levels from modules/s3_config)
  resources_path = "${path.module}/../../resources"
}

# ==============================================================================
# DYNAMIC UPLOADS (The Fix)
# ==============================================================================

# 1. Upload ALL Grafana Configs (Dashboards, Datasources, Notifiers) recursively
resource "aws_s3_object" "grafana_files" {
  # This finds ALL files inside 'resources/grafana/' 
  for_each = fileset("${local.resources_path}/grafana", "**/*")

  bucket = local.config_bucket_id
  key    = "grafana/${each.value}"
  source = "${local.resources_path}/grafana/${each.value}"

  # Triggers update if file content changes
  etag = filemd5("${local.resources_path}/grafana/${each.value}")
}

# 2. Upload Prometheus Config
resource "aws_s3_object" "prometheus_config" {
  bucket = local.config_bucket_id
  key    = "prometheus/prometheus.yml"
  source = "${local.resources_path}/prometheus/prometheus.yml"
  etag   = filemd5("${local.resources_path}/prometheus/prometheus.yml")
}

# 3. Upload IoT Simulator Script
resource "aws_s3_object" "iot_script" {
  bucket = local.config_bucket_id
  key    = "app/iot-simulator.py"
  source = "${local.resources_path}/app/iot-simulator.py"
  etag   = filemd5("${local.resources_path}/app/iot-simulator.py")
}

# # 4. Upload Certificates
# resource "aws_s3_object" "certs" {
#   for_each = var.enable_cert_upload ? toset([
#     var.iot_cert_files.root_ca,
#     var.iot_cert_files.device_cert,
#     var.iot_cert_files.private_key
#   ]) : toset([])

#   # bucket = aws_s3_bucket.config.bucket
#   # key    = "certs/${each.value}"

#   bucket = local.cert_bucket_id
#   key    = each.value
#   source = "${local.resources_path}/certs/${each.value}"
#   etag   = filemd5("${local.resources_path}/certs/${each.value}")

#   content_type = "application/octet-stream"
# }

# 4. Upload Certificates
resource "aws_s3_object" "certs" {
  for_each = var.enable_cert_upload ? var.cert_files : {}

  bucket = local.cert_bucket_id
  key    = each.value
  source = "${local.resources_path}/certs/${each.value}"
  etag   = filemd5("${local.resources_path}/certs/${each.value}")
}
