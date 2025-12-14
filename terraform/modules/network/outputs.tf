# modules/network/outputs.tf

output "vpc_id" {
  value = aws_vpc.this.id
}

output "public_subnets" {
  description = "List of public subnet IDs (Required by ECS)"
  value       = aws_subnet.public[*].id  # The [*] syntax returns all IDs as a list 
}

output "ecs_security_group_id" {
  description = "The security group ID to attach to ECS tasks"
  # We map the existing 'ec2_sg' to this output
  value       = aws_security_group.ecs_sg.id
}