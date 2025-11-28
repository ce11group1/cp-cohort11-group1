output "thing_name" {
  description = "IoT Thing name"
  value       = aws_iot_thing.this.name
}

output "policy_name" {
  description = "IoT Policy name"
  value       = aws_iot_policy.this.name
}

output "certificate_arn" {
  description = "Certificate ARN (if created)"
  value       = var.create_certificate ? aws_iot_certificate.this[0].arn : null
}

output "certificate_pem" {
  description = "Device certificate (PEM). Download & store securely."
  value       = var.create_certificate ? aws_iot_certificate.this[0].certificate_pem : null
  sensitive   = true
}

output "private_key" {
  description = "Device private key. Download & store securely."
  value       = var.create_certificate ? aws_iot_certificate.this[0].private_key : null
  sensitive   = true
}

output "public_key" {
  description = "Device public key"
  value       = var.create_certificate ? aws_iot_certificate.this[0].public_key : null
  sensitive   = true
}

output "rule_name" {
  description = "IoT Topic Rule name"
  value       = aws_iot_topic_rule.telemetry_rule.name
}
