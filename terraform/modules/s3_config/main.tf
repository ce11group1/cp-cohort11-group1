# modules/s3_config/main.tf

resource "aws_s3_bucket" "config_bucket" {
  count         = var.create_buckets ? 1 : 0
  bucket        = var.config_s3_bucket
  force_destroy = var.environment == "prod" ? false : true
  tags          = merge(var.tags, { Name = var.config_s3_bucket })
}

resource "aws_s3_bucket" "cert_bucket" {
  count         = var.create_buckets ? 1 : 0
  bucket        = var.cert_s3_bucket
  force_destroy = var.environment == "prod" ? false : true
  tags          = merge(var.tags, { Name = var.cert_s3_bucket })
}

data "aws_s3_bucket" "config_bucket" {
  count  = var.create_buckets ? 0 : 1
  bucket = var.config_s3_bucket
}

data "aws_s3_bucket" "cert_bucket" {
  count  = var.create_buckets ? 0 : 1
  bucket = var.cert_s3_bucket
}

locals {
  # Define the base path to the resources folder
  # Logic: Up from 'modules/s3_config' (2 levels) -> 'resources'
  resources_path = "${path.module}/../../resources"

  config_bucket = var.create_buckets ? aws_s3_bucket.config_bucket[0].bucket : data.aws_s3_bucket.config_bucket[0].bucket
  cert_bucket   = var.create_buckets ? aws_s3_bucket.cert_bucket[0].bucket : data.aws_s3_bucket.cert_bucket[0].bucket

  dashboard_files = {
    "anomalies/anomalies.json" = "grafana/provisioning/dashboards/anomalies/anomalies.json"
    #  "system-health/system-health.json"          = "grafana/provisioning/dashboards/system-health/system-health.json"
    #  "latency/latency.json"                      = "grafana/provisioning/dashboards/latency/latency.json"
    "iot-sim/iot-sim-dashboard4.json"            = "grafana/provisioning/dashboards/iot-sim/iot-sim-dashboard4.json"
    "executive-overview/executive-overview.json" = "grafana/provisioning/dashboards/executive-overview/executive-overview.json"
  }
}

# Then copy all your existing aws_s3_object resources here, e.g.:

resource "aws_s3_object" "prometheus_config" {
  bucket = local.config_bucket
  key    = "prometheus/prometheus.yml"
  source = "${local.resources_path}/prometheus/prometheus.yml"
  etag   = filemd5("${local.resources_path}/prometheus/prometheus.yml")
}

# ... grafana_ini, grafana_dashboards_config, grafana_dashboards, notifiers,
# alerting YAMLs, datasources, iot_simulator_script, certs ...

resource "aws_s3_object" "grafana_ini" {
  bucket = local.config_bucket
  key    = "grafana/provisioning/grafana.ini"
  source = "${local.resources_path}/grafana/provisioning/grafana.ini"
  etag   = filemd5("${local.resources_path}/grafana/provisioning/grafana.ini")
}

resource "aws_s3_object" "grafana_dashboards_config" {
  bucket = local.config_bucket #aws_s3_bucket.config_bucket.bucket
  key    = "grafana/provisioning/dashboards/dashboards.yaml"
  source = "${local.resources_path}/grafana/provisioning/dashboards/dashboards.yaml"
  etag   = filemd5("${local.resources_path}/grafana/provisioning/dashboards/dashboards.yaml")
}

resource "aws_s3_object" "grafana_dashboards" {
  for_each = local.dashboard_files
  bucket   = local.config_bucket
  key      = "grafana/provisioning/dashboards/${each.key}"
  source   = "${local.resources_path}/${each.value}"
  etag     = filemd5("${local.resources_path}/${each.value}")
}

resource "aws_s3_object" "grafana_notifier_email" {
  bucket = local.config_bucket
  key    = "grafana/provisioning/notifiers/contact-points.yaml"
  source = "${local.resources_path}/grafana/provisioning/notifiers/contact-points.yaml"
  etag   = filemd5("${local.resources_path}/grafana/provisioning/notifiers/contact-points.yaml")
}

resource "aws_s3_object" "grafana_alerting_anomaly_alerts" {
  bucket = local.config_bucket
  key    = "grafana/provisioning/alerting/anomaly-alerts.yaml"
  source = "${local.resources_path}/grafana/provisioning/alerting/anomaly-alerts.yaml"
  etag   = filemd5("${local.resources_path}/grafana/provisioning/alerting/anomaly-alerts.yaml")
}

# resource "aws_s3_object" "grafana_alerting_notify_policies" {
#   bucket = local.config_bucket
#   key    = "grafana/provisioning/alerting/notification-policies.yaml"
#   source = "${local.resources_path}/grafana/provisioning/alerting/notification-policies.yaml"
#   etag   = filemd5("${local.resources_path}/grafana/provisioning/alerting/notification-policies.yaml")
# }

resource "aws_s3_object" "grafana_alerting_mute_timings" {
  bucket = local.config_bucket
  key    = "grafana/provisioning/alerting/mute-timings.yaml"
  source = "${local.resources_path}/grafana/provisioning/alerting/mute-timings.yaml"
  etag   = filemd5("${local.resources_path}/grafana/provisioning/alerting/mute-timings.yaml")
}

resource "aws_s3_object" "grafana_datasources" {
  bucket = local.config_bucket
  key    = "grafana/provisioning/datasources/datasources.yaml"
  source = "${local.resources_path}/grafana/provisioning/datasources/datasources.yaml"
  etag   = filemd5("${local.resources_path}/grafana/provisioning/datasources/datasources.yaml")
}

resource "aws_s3_object" "iot_simulator_script" {
  bucket = local.config_bucket
  key    = "app/iot-simulator.py"
  source = "${local.resources_path}/app/iot-simulator.py"
  etag   = filemd5("${local.resources_path}/app/iot-simulator.py")
}

############################################
# Certificates Upload
############################################
resource "aws_s3_object" "certs" {
  for_each = var.enable_cert_upload ? var.cert_files : {}

  bucket = local.cert_bucket
  key    = each.value
  source = "${local.resources_path}/certs/${each.value}"
  etag   = filemd5("${local.resources_path}/certs/${each.value}")
}
