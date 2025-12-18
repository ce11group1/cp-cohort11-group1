# --- Infrastructure Info ---
output "vpc_id" {
  description = "The ID of the VPC created"
  value       = module.app.vpc_id
}

output "iot_endpoint" {
  description = "The AWS IoT Core endpoint URL"
  value       = module.app.iot_endpoint
}

output "s3_config_bucket" {
  description = "S3 bucket where Grafana/Prometheus configs must be uploaded"
  value       = module.app.config_bucket_name # Assuming this is the correct output name from the app module
}

output "s3_cert_bucket" {
  description = "S3 bucket where IoT certificates must be uploaded"
  value       = module.app.s3_cert_bucket # Assuming this is the correct output name from the app module
}

# --- ECS & Docker Info ---
output "ecs_cluster_name" {
  description = "The name of the ECS Cluster"
  value       = module.app.ecs_cluster_name
}

output "ecs_service_name" {
  description = "The name of the ECS Service running the simulator"
  value       = module.app.ecs_service_name
}

output "iot_certificate_arn" {
  value = module.app.iot_certificate_arn
}

output "iot_certificate_id" {
  value = module.app.iot_certificate_id
}

output "iot_thing_name" {
  value = module.app.iot_thing_name
}

output "iot_policy_name" {
  value = module.app.iot_policy_name
}

# --- Manual IP/Console Access (Fixed Interpolation) ---

output "ecs_console_url" {
  description = "Click here to find your running Task and its Public IP"
  # FIX: Added ${} around module references
  value = "https://${var.region}.console.aws.amazon.com/ecs/v2/clusters/${module.app.ecs_cluster_name}/services/${module.app.ecs_service_name}/tasks?region=${var.region}"
}

output "grafana_port_info" {
  value = "Once you find the Public IP of the task in the link above, access Grafana at: http://<PUBLIC-IP>:3000"
}

output "prometheus_port_info" {
  value = "Once you find the Public IP of the task in the link above, access Prometheus at: http://<PUBLIC-IP>:9090"
}

# --- ECR & ALB Access (Fixed Interpolation) ---

output "ecr_repository_url" {
  description = "The URL of the ECR repository to push images to"
  value       = module.app.ecr_repository_url
}

output "app_url" {
  description = "Public URL for the IoT Simulator Grafana Dashboard"
  # FIX: Added ${} around module reference
  value = "http://${module.app.alb_dns}"
}

output "docker_push_command" {
  description = "Helper command to push your image"
  # FIX: Corrected the module path to be consistent with 'module.app.ecr_repository_url'
  value = <<EOT
aws ecr get-login-password --region ${var.region} | docker login --username AWS --password-stdin ${module.app.ecr_repository_url}
docker build -t iot-simulator ../../resources/app
docker tag iot-simulator:latest ${module.app.ecr_repository_url}:latest
docker push ${module.app.ecr_repository_url}:latest
EOT
}