locals {
  frontend_origin_id = "s3-frontend"
  alb_origin_id      = "alb-backend"
  backend_patterns   = ["/api/*", "/ws/*"]
}

module "distribution" {
  source              = "../cloudfront"
  default_root_object = "index.html"
  origins = [
    {
      id                       = local.frontend_origin_id
      domain_name              = local.bucket_regional_domain_name
      origin_access_control_id = aws_cloudfront_origin_access_control.oac.id
    },
    {
      id            = local.alb_origin_id
      domain_name   = aws_lb.alb.dns_name
      vpc_origin_id = aws_cloudfront_vpc_origin.alb_origin.id
    }
  ]
  default_cache_behavior = {
    allowed_methods               = ["GET", "HEAD"]
    cached_methods                = ["GET", "HEAD"]
    target_origin_id              = local.frontend_origin_id
    managed_cache_policy          = "CachingOptimized"
    managed_origin_request_policy = "CORS-S3Origin"
  }
  ordered_cache_behaviors = [for pattern in local.backend_patterns : {
    path_pattern                  = pattern
    allowed_methods               = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods                = ["GET", "HEAD"]
    target_origin_id              = local.alb_origin_id
    managed_cache_policy          = "CachingDisabled"
    managed_origin_request_policy = "AllViewer"
  }]
  web_acl_id = aws_wafv2_web_acl.waf.arn
}

data "aws_iam_policy_document" "bucket_policy" {
  statement {
    effect    = "Allow"
    actions   = ["s3:GetObject"]
    resources = ["${local.bucket_arn}/*"]
    condition {
      test     = "StringEquals"
      values   = [module.distribution.arn]
      variable = "AWS:SourceArn"
    }
    principals {
      identifiers = ["cloudfront.amazonaws.com"]
      type        = "Service"
    }
  }
}

resource "aws_s3_bucket_policy" "policy" {
  bucket = local.bucket_name
  policy = data.aws_iam_policy_document.bucket_policy.json
}

resource "aws_cloudfront_origin_access_control" "oac" {
  name                              = "s3-oac"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}