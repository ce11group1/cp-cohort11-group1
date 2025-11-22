output "vpc_id" {
  value = module.vpc.vpc_id
}

output "public_subnet_id" {
  value = module.vpc.public_subnet_id
}

output "ec2_instance_id" {
  value = module.ec2.instance_id
}

output "ec2_security_group_id" {
  value = module.ec2.security_group_id
}
