resource "aws_instance" "app" {
  ami           = "ami-0889a44b331db0194"
  instance_type = "t2.micro"

  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.ec2_sg.id]
  associate_public_ip_address = true

  tags = {
    Name = "project-ec2"
  }
}
resource "aws_instance" "app" {
  ami           = "ami-0889a44b331db0194"
  instance_type = "t2.micro"

  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.ec2_gp1.id]
  associate_public_ip_address = true

  tags = {
    Name = "capstone-grp1-ec2"
  }
}

