terraform {
  required_version = ">=1.10.6"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.13.0"
    }
  }
}

locals {
  managed_prefix = "Managed-"
  managed_origin_policies = distinct(concat([var.default_cache_behavior.managed_origin_request_policy],
  [for o in var.ordered_cache_behaviors : o.managed_origin_request_policy]))
  managed_cache_policies = distinct(concat([var.default_cache_behavior.managed_cache_policy],
    [for o in var.ordered_cache_behaviors : o.managed_cache_policy]
  ))
}

data "aws_cloudfront_cache_policy" "policies" {
  for_each = toset(local.managed_cache_policies)
  name     = "${local.managed_prefix}${each.value}"
}

data "aws_cloudfront_origin_request_policy" "policies" {
  for_each = toset(local.managed_origin_policies)
  name     = "${local.managed_prefix}${each.value}"
}

locals {
  origin_policies_ids = {
    for p in data.aws_cloudfront_origin_request_policy.policies : trimprefix(p.name, local.managed_prefix) => p.id
  }
  cache_policies_ids = {
    for p in data.aws_cloudfront_cache_policy.policies : trimprefix(p.name, local.managed_prefix) => p.id
  }
}

resource "aws_cloudfront_distribution" "distribution" {
  enabled             = true
  default_root_object = var.default_root_object

  dynamic "origin" {
    for_each = var.origins
    content {
      origin_id                = origin.value.id
      domain_name              = origin.value.domain_name
      origin_access_control_id = origin.value.origin_access_control_id
      dynamic "vpc_origin_config" {
        for_each = origin.value.vpc_origin_id == null ? [] : [1]
        content {
          vpc_origin_id = origin.value.vpc_origin_id
        }
      }
    }
  }

  dynamic "ordered_cache_behavior" {
    for_each = var.ordered_cache_behaviors
    content {
      allowed_methods          = ordered_cache_behavior.value.allowed_methods
      cached_methods           = ordered_cache_behavior.value.cached_methods
      path_pattern             = ordered_cache_behavior.value.path_pattern
      target_origin_id         = ordered_cache_behavior.value.target_origin_id
      viewer_protocol_policy   = "https-only"
      origin_request_policy_id = local.origin_policies_ids[ordered_cache_behavior.value.managed_origin_request_policy]
      cache_policy_id          = local.cache_policies_ids[ordered_cache_behavior.value.managed_cache_policy]
    }
  }

  default_cache_behavior {
    allowed_methods          = var.default_cache_behavior.allowed_methods
    cached_methods           = var.default_cache_behavior.cached_methods
    target_origin_id         = var.default_cache_behavior.target_origin_id
    viewer_protocol_policy   = "https-only"
    origin_request_policy_id = local.origin_policies_ids[var.default_cache_behavior.managed_origin_request_policy]
    cache_policy_id          = local.cache_policies_ids[var.default_cache_behavior.managed_cache_policy]
  }

  dynamic "custom_error_response" {
    for_each = var.custom_error_responses
    content {
      error_code         = custom_error_response.value.error_code
      response_code      = custom_error_response.value.response_code
      response_page_path = custom_error_response.value.response_page_path
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

  web_acl_id = var.web_acl_id
}