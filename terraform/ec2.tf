resource "aws_instance" "app" {
  ami           = "ami-0fa377108253bf620" # Amazon Linux 2023 (Singapore)
  instance_type = "t2.micro"

  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.ec2_gp1.id]

  associate_public_ip_address = true

  tags = {
    Name = "capstone-gp1-ec2"
  }
}
