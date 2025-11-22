resource "aws_instance" "app" {
  ami           = "ami-0889a44b331db0194"
  instance_type = "t2.micro"

  subnet_id                   = aws_subnet.public.id
  vpc_security_group_ids      = [aws_security_group.ec2_gp1.id]
  associate_public_ip_address = true

  tags = {
    Name = "capstone-grp1-ec2"
  }
}

#=====Secruity Group======#

resource "aws_security_group" "ec2_gp1" {
  name        = "ec2-gp1"
  description = "Allow SSH and HTTP"
  vpc_id      = var.vpc_id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "ec2-gp1" }
}