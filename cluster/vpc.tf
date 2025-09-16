locals {
  prefix_length = tonumber(split("/", var.cidr)[1])
  desired_mask  = 32 - ceil(log(var.subnet_size, 2))
  new_bits      = local.desired_mask - local.prefix_length
  zones         = length(var.availability_zones)
  vpc_name      = "${var.cluster_name}-vpc"
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

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.vpc.id

  tags = {
    Name : "${local.vpc_name}-private-routes"
  }
}

resource "aws_route_table_association" "private" {
  count          = local.zones
  route_table_id = aws_route_table.private.id
  subnet_id      = aws_subnet.private[count.index].id
}

module "fck-nat" {
  source = "git::https://github.com/RaJiska/terraform-aws-fck-nat.git"

  name          = "${var.cluster_name}-fck-nat"
  vpc_id        = aws_vpc.vpc.id
  subnet_id     = aws_subnet.public[0].id
  instance_type = "t4g.nano"

  update_route_tables = true
  route_tables_ids = {
    "private" = aws_route_table.private.id
  }
}