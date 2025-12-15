############################################
# Networking
############################################

# Get Available Zones dynamically
data "aws_availability_zones" "available" {
  state = "available"
}

# VPC
resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags                 = merge(var.tags, { Name = "${var.name_prefix}-vpc" })
}

# 2. Create Multiple Subnets (One per CIDR provided)
resource "aws_subnet" "public" {
  count      = length(var.public_subnet_cidrs) # Create as many as there are CIDRs
  vpc_id     = aws_vpc.this.id
  cidr_block = var.public_subnet_cidrs[count.index]

  # Automatically pick a different AZ for each subnet
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true

  tags = merge(var.tags, { Name = "${var.name_prefix}-public-subnet-${count.index + 1}" })
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.this.id
  tags   = merge(var.tags, { Name = "${var.name_prefix}-igw" })
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  tags = merge(var.tags, { Name = "${var.name_prefix}-public-rt" })
}

# 3. Associate ALL subnets with the Route Table
resource "aws_route_table_association" "public_assoc" {
  count          = length(var.public_subnet_cidrs)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

############################################
# Security Group
############################################
# (Your Security Group code remains the same)
resource "aws_security_group" "ecs_sg" {
  name        = "${var.name_prefix}-ecs-sg"
  tags        = merge(var.tags, { Name = "${var.name_prefix}-ecs-sg" })
  description = "Allow SSH (22), Grafana (3000), Prometheus (9090)"
  vpc_id      = aws_vpc.this.id

  dynamic "ingress" {
    for_each = [22, 3000, 9090]
    content {
      from_port   = ingress.value
      to_port     = ingress.value
      protocol    = "tcp"
      cidr_blocks = [var.allowed_cidr]
    }
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}