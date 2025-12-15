# modules/s3_config/outputs.tf

output "config_bucket_name" {
  value = local.config_bucket_id
}

output "cert_bucket_name" {
  value = local.cert_bucket_id
}
