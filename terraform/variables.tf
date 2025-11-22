variable "aws_region" {
  description = "AWS region to deploy the infrastructure"
  type        = string
  default     = "us-east-1"
}

variable "vpc_cidr" {
  description = "VPC CIDR block"
  type        = string
  default     = "10.0.0.0/16"
}

variable "ec2_instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t2.micro"
}

variable "ec2_ami_id" {
  description = "AMI ID for EC2 (Amazon Linux 2023 - us-east-1)"
  type        = string
  default     = "ami-0889a44b331db0194"
}
