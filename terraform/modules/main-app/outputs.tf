# --- Infrastructure Info ---
output "vpc_id" {
  description = "The ID of the VPC created"
  value       = module.network.vpc_id
}

output "iot_endpoint" {
  description = "The AWS IoT Core endpoint URL"
  value       = module.iot.iot_endpoint
}

output "s3_config_bucket" {
  description = "S3 bucket where Grafana/Prometheus configs must be uploaded"
  value       = module.s3_config.config_bucket_name
}

output "s3_cert_bucket" {
  description = "S3 bucket where IoT certificates must be uploaded"
  value       = module.s3_config.cert_bucket_name
}

# --- ECS & Docker Info ---
output "ecs_cluster_name" {
  description = "The name of the ECS Cluster"
  value       = aws_ecs_cluster.main_cluster.name
}

output "ecs_service_name" {
  description = "The name of the ECS Service running the simulator"
  value       = module.iot_ecs.service_name
  # Note: Ensure you add 'output "service_name" { value = aws_ecs_service.main.name }' to your module/iot-simulator-ecs/outputs.tf
}

output "iot_certificate_arn" {
  value = module.iot.certificate_arn
}

output "iot_certificate_id" {
  value = module.iot.certificate_id
}

output "iot_thing_name" {
  value = module.iot.iot_thing_name
}

output "iot_policy_name" {
  value = module.iot.iot_policy_name
}

output "cert_bucket_name" {
  value = module.s3_config.cert_bucket_name
}

output "config_bucket_name" {
  value = module.s3_config.config_bucket_name
}

# Since ECS tasks get dynamic IPs, we cannot output a hardcoded URL.
# Instead, we output the ECS Service URL where you can find the running task's public IP.

output "ecs_console_url" {
  description = "Click here to find your running Task and its Public IP"
  value       = "https://${var.region}.console.aws.amazon.com/ecs/v2/clusters/${aws_ecs_cluster.main_cluster.name}/services/${module.iot_ecs.service_name}/tasks?region=${var.region}"
}

output "grafana_port_info" {
  value = "Once you find the Public IP of the task in the link above, access Grafana at: http://<PUBLIC-IP>:3000"
}

output "prometheus_port_info" {
  value = "Once you find the Public IP of the task in the link above, access Prometheus at: http://<PUBLIC-IP>:9090"
}

# output "ecr_repository_url" {
#   description = "Command to tag your docker image"
#   value       = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.region}.amazonaws.com/iot-simulator"
# }

output "ecr_repository_url" {
  description = "The URL of the ECR repository to push images to"
  value       = module.ecr_simulator.repository_url # <--- Updated path
}

output "app_url" {
  description = "Public URL for the IoT Simulator Grafana Dashboard"
  value       = "http://${module.shared_alb.dns_name}"
}

output "docker_push_command" {
  description = "Helper command to push your image"
  # Update build context to './resources/app'
  value = <<EOT
aws ecr get-login-password --region ${var.region} | docker login --username AWS --password-stdin ${module.ecr_simulator.repository_url}
docker build -t iot-simulator ../../resources/app
docker tag iot-simulator:latest ${module.ecr_simulator.repository_url}:latest
docker push ${module.ecr_simulator.repository_url}:latest
EOT
}

output "alb_dns" {
  value = module.shared_alb.dns_name
}