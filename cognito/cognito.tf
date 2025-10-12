resource "aws_cognito_user_pool" "pool" {
  name           = "raccoon-pool"
  user_pool_tier = "LITE"
  password_policy {
    minimum_length    = 10
    require_lowercase = true
    require_numbers   = true
    require_symbols   = true
    require_uppercase = true
  }
  schema {
    attribute_data_type = "String"
    name                = "avatar_location"
    mutable             = true
    required            = false
    string_attribute_constraints {
      max_length = 128
      min_length = 0
    }
  }
}

resource "aws_cognito_user_pool_domain" "domain" {
  domain                = "raccoon"
  user_pool_id          = aws_cognito_user_pool.pool.id
  managed_login_version = 1
}

resource "aws_cognito_user_pool_client" "client" {
  name                                 = "frontend"
  generate_secret                      = false
  user_pool_id                         = aws_cognito_user_pool.pool.id
  callback_urls                        = ["https://${local.domain}/callback"]
  logout_urls                          = ["https://${local.domain}/logout"]
  allowed_oauth_flows                  = ["code"]
  allowed_oauth_scopes                 = ["openid", "profile", "email"]
  allowed_oauth_flows_user_pool_client = true
  supported_identity_providers         = ["COGNITO"]
}

resource "aws_cognito_user_pool_client" "admin_client" {
  name         = "admin-client"
  user_pool_id = aws_cognito_user_pool.pool.id
  explicit_auth_flows = [
    "ALLOW_ADMIN_USER_PASSWORD_AUTH",
  ]
  generate_secret        = false
  access_token_validity  = 10
  id_token_validity      = 10
  refresh_token_validity = 1
  token_validity_units {
    id_token      = "minutes"
    access_token  = "minutes"
    refresh_token = "hours"
  }
  supported_identity_providers = ["COGNITO"]
}