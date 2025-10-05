output "cognito_hosted_domain" {
  value = "https://${aws_cognito_user_pool_domain.domain.domain}.auth.${var.region}.amazoncognito.com"
}

output "frontend_client_id" {
  value = aws_cognito_user_pool_client.client.id
}

output "discovery_endpoints" {
  value = {
    openid_configuration = "https://cognito-idp.${var.region}.amazonaws.com/${aws_cognito_user_pool.pool.id}/.well-known/openid-configuration"
    jwks                 = "https://cognito-idp.${var.region}.amazonaws.com/${aws_cognito_user_pool.pool.id}/.well-known/jwks.json"
  }
}

output "admin_client_id" {
  value = aws_cognito_user_pool_client.admin_client.id
}

output "user_pool_id" {
  value = aws_cognito_user_pool.pool.id
}