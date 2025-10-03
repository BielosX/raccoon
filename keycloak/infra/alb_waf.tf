resource "aws_wafv2_ip_set" "admin_ip" {
  name               = "admin-allowed-ip"
  scope              = "REGIONAL"
  ip_address_version = "IPV4"
  addresses          = ["${var.admin_ip}/32"]
}

resource "aws_wafv2_web_acl" "alb_waf" {
  name_prefix = "alb-block-auth-admin-"
  scope       = "REGIONAL"

  default_action {
    block {}
  }

  rule {
    name     = "RateLimit"
    priority = 1
    action {
      block {}
    }
    statement {
      rate_based_statement {
        limit              = 500
        aggregate_key_type = "IP"
      }
    }
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "RateLimit"
      sampled_requests_enabled   = true
    }
  }

  rule {
    name     = "BlockAdmin"
    priority = 2
    action {
      allow {}
    }
    statement {
      and_statement {
        statement {
          ip_set_reference_statement {
            arn = aws_wafv2_ip_set.admin_ip.arn
          }
        }
        statement {
          byte_match_statement {
            search_string = "/admin"
            field_to_match {
              uri_path {}
            }
            text_transformation {
              priority = 0
              type     = "URL_DECODE"
            }
            text_transformation {
              priority = 1
              type     = "LOWERCASE"
            }
            positional_constraint = "STARTS_WITH"
          }
        }
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "BlockAdmin"
      sampled_requests_enabled   = true
    }
  }

  rule {
    name     = "AllowPublicPaths"
    priority = 3
    action {
      allow {}
    }
    statement {
      byte_match_statement {
        search_string = "/"
        field_to_match {
          uri_path {}
        }
        text_transformation {
          priority = 0
          type     = "NONE"
        }
        positional_constraint = "STARTS_WITH"
      }
    }
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "AllowPublicPaths"
      sampled_requests_enabled   = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = false
    metric_name                = "temp"
    sampled_requests_enabled   = false
  }
}

resource "aws_wafv2_web_acl_association" "alb_waf_association" {
  resource_arn = aws_lb.alb.arn
  web_acl_arn  = aws_wafv2_web_acl.alb_waf.arn
}