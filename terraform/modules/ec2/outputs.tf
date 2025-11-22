output "security_group_id" {
  value = aws_security_group.ec2_grp1.id
}

output "instance_id" {
  value = aws_instance.app.id
}

