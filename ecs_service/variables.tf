variable "name" {
  type = string
}

variable "cluster_name" {
  type = string
}

variable "container_definitions" {
  type = list(object({
    name        = string
    environment = map(string)
    port_mappings = list(object({
      container_port = number
      name           = optional(string)
    }))
    essential  = bool
    privileged = bool
    image      = string
    user       = string
  }))
}

variable "target_groups" {
  type = list(object({
    container_name   = string
    container_port   = number
    target_group_arn = string
  }))
}

variable "cpu" {
  type = number
}

variable "memory" {
  type = number
}

variable "region" {
  type = string
}

variable "desired_count" {
  type = number
}

variable "subnets" {
  type = list(string)
}

variable "security_groups" {
  type = list(string)
}

variable "enable_exec_command" {
  type    = bool
  default = false
}

variable "service_connect" {
  type = object({
    namespace = string
    services = list(object({
      port_name      = string
      discovery_name = string
      port           = string
    }))
  })
  default = null
}