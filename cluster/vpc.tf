locals {
  prefix_length = tonumber(split("/", var.cidr)[1])
  desired_mask  = 32 - ceil(log(var.subnet_size, 2))
  new_bits      = local.desired_mask - local.prefix_length
  zones         = length(var.availability_zones)
  vpc_name      = "${var.cluster_name}-vpc"
  ecr_endpoints = ["com.amazonaws.${var.region}.ecr.dkr", "com.amazonaws.${var.region}.ecr.api"]
}

resource "aws_vpc" "vpc" {
  enable_dns_hostnames = true
  enable_dns_support   = true
  cidr_block           = var.cidr
  tags = {
    Name : local.vpc_name
  }
}

resource "aws_subnet" "public" {
  count             = local.zones
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = cidrsubnet(var.cidr, local.new_bits, count.index)
  availability_zone = var.availability_zones[count.index]
  tags = {
    Name : "${local.vpc_name}-public-subnet-${count.index}"
  }
}

resource "aws_subnet" "private" {
  count             = length(var.availability_zones)
  availability_zone = var.availability_zones[count.index]
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = cidrsubnet(var.cidr, local.new_bits, count.index + local.zones)
  tags = {
    Name : "${local.vpc_name}-private-subnet-${count.index}"
  }
}

resource "aws_internet_gateway" "internet_gateway" {
  vpc_id = aws_vpc.vpc.id
  tags = {
    Name : "${local.vpc_name}-igw"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.internet_gateway.id
  }

  tags = {
    Name : "${local.vpc_name}-public-routes"
  }
}

resource "aws_route_table_association" "public" {
  count          = local.zones
  route_table_id = aws_route_table.public.id
  subnet_id      = aws_subnet.public[count.index].id
}

resource "aws_security_group" "ecr_endpoint_sg" {
  vpc_id      = aws_vpc.vpc.id
  name_prefix = "ecr-endpoint-sg"
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.cidr]
  }
}

resource "aws_vpc_endpoint" "ecr" {
  for_each            = toset(local.ecr_endpoints)
  vpc_id              = aws_vpc.vpc.id
  service_name        = each.value
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.private[*].id
  security_group_ids  = [aws_security_group.ecr_endpoint_sg.id]
  private_dns_enabled = true
}
