output "arn" {
  value = aws_cloudfront_distribution.distribution.arn
}

output "id" {
  value = aws_cloudfront_distribution.distribution.id
}

output "domain" {
  value = aws_cloudfront_distribution.distribution.domain_name
}