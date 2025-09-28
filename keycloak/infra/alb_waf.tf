resource "aws_wafv2_web_acl" "alb_waf" {
  name_prefix = "alb-block-auth-admin-"
  scope       = "REGIONAL"
  default_action {
    allow {}
  }

  rule {
    name     = "BlockAuthAdmin"
    priority = 1
    action {
      block {}
    }
    statement {
      byte_match_statement {
        search_string = "/auth/admin"
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

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "BlockAuthAdmin"
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
  resource_arn = local.alb_arn
  web_acl_arn  = aws_wafv2_web_acl.alb_waf.arn
}