variable "ordered_cache_behaviors" {
  type = list(object({
    path_pattern                  = string
    allowed_methods               = list(string)
    cached_methods                = list(string)
    target_origin_id              = string
    managed_origin_request_policy = string
    managed_cache_policy          = string
  }))
  default = []
}

variable "default_cache_behavior" {
  type = object({
    allowed_methods               = list(string)
    cached_methods                = list(string)
    target_origin_id              = string
    managed_origin_request_policy = string
    managed_cache_policy          = string
  })
}

variable "web_acl_id" {
  type    = string
  default = null
}

variable "origins" {
  type = list(object({
    id                       = string
    domain_name              = string
    origin_access_control_id = optional(string)
    vpc_origin_id            = optional(string)
  }))
}

variable "default_root_object" {
  type    = string
  default = null
}

variable "custom_error_responses" {
  type = list(object({
    error_code         = number
    response_code      = number
    response_page_path = string
  }))
  default = []
}