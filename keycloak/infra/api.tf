resource "aws_apigatewayv2_api" "api" {
  name          = "keycloak"
  protocol_type = "HTTP"
}

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.api.id
  name        = "$default"
  auto_deploy = true
}

resource "aws_security_group" "link_sg" {
  vpc_id = local.vpc_id

  egress {
    cidr_blocks = [local.vpc_cidr]
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
  }
}

resource "aws_apigatewayv2_vpc_link" "link" {
  name               = "keycloak-vpc-link"
  security_group_ids = [aws_security_group.link_sg.id]
  subnet_ids         = local.private_subnet_ids
}

resource "aws_apigatewayv2_integration" "alb" {
  api_id             = aws_apigatewayv2_api.api.id
  integration_method = "ANY"
  integration_type   = "HTTP_PROXY"
  integration_uri    = aws_lb_listener.listener.arn
  connection_type    = "VPC_LINK"
  connection_id      = aws_apigatewayv2_vpc_link.link.id
}

resource "aws_apigatewayv2_route" "route" {
  api_id    = aws_apigatewayv2_api.api.id
  route_key = "ANY /{proxy+}"
  target    = "integrations/${aws_apigatewayv2_integration.alb.id}"
}