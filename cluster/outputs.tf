output "vpc_id" {
  value = aws_vpc.vpc.id
}

output "public_subnet_ids" {
  value = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  value = aws_subnet.private[*].id
}

output "vpc_cidr" {
  value = aws_vpc.vpc.cidr_block
}

output "default_namespace_arn" {
  value = aws_service_discovery_http_namespace.default.arn
}