resource "aws_wafv2_web_acl" "waf" {
  name   = "cloudfront-rate-limit"
  scope  = "CLOUDFRONT"
  region = "us-east-1" // For CloudFront

  default_action {
    allow {}
  }

  rule {
    name     = "RateLimit100RequestsPerMinute"
    priority = 1

    action {
      block {}
    }

    statement {
      rate_based_statement {
        limit              = 500 // 500 per 5 minutes
        aggregate_key_type = "IP"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "RateLimit100PerMinute"
      sampled_requests_enabled   = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = false
    metric_name                = "temp"
    sampled_requests_enabled   = false
  }
}