locals {
  frontend_origin_id = "s3-frontend"
  alb_origin_id      = "alb-backend"
}

resource "aws_cloudfront_distribution" "distribution" {
  enabled             = true
  default_root_object = "index.html"

  origin {
    origin_id                = local.frontend_origin_id
    domain_name              = local.bucket_regional_domain_name
    origin_access_control_id = aws_cloudfront_origin_access_control.oac.id
  }

  origin {
    origin_id   = local.alb_origin_id
    domain_name = aws_lb.alb.dns_name
    vpc_origin_config {
      vpc_origin_id = aws_cloudfront_vpc_origin.alb_origin.id
    }
  }

  ordered_cache_behavior {
    path_pattern           = "/app/*"
    allowed_methods        = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = local.alb_origin_id
    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 0
    max_ttl                = 0
    /*
      AllViewer
      This policy includes all values (headers, cookies, and query strings) from the viewer request.
      https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/using-managed-origin-request-policies.html#managed-origin-request-policy-all-viewer
     */
    origin_request_policy_id = "216adef6-5c7f-47e4-b989-5492eafa07d3"
    /*
      CachingDisabled
      https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/using-managed-cache-policies.html#managed-cache-policy-caching-disabled
     */
    cache_policy_id = "4135ea2d-6df8-44a3-9df3-4b5a84be39ad"
  }

  default_cache_behavior {
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = local.frontend_origin_id
    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 3600
    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  web_acl_id = aws_wafv2_web_acl.waf.arn
}

data "aws_iam_policy_document" "bucket_policy" {
  statement {
    effect    = "Allow"
    actions   = ["s3:GetObject"]
    resources = ["${local.bucket_arn}/*"]
    condition {
      test     = "StringEquals"
      values   = [aws_cloudfront_distribution.distribution.arn]
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