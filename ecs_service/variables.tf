variable "name" {
  type = string
}

variable "cluster_name" {
  type = string
}

variable "container_definitions" {
  type = list(object({
    name        = string
    environment = optional(map(string), {})
    linux_parameters = optional(object({
      init_process_enabled = optional(bool)
    }))
    depends_on = optional(list(object({
      condition      = string
      container_name = string
    })), [])
    secrets = optional(list(object({
      name       = string
      value_from = string
    })), [])
    port_mappings = optional(list(object({
      container_port = number
      name           = optional(string)
    })), [])
    essential  = bool
    privileged = bool
    image      = string
    user       = optional(string)
    command    = optional(list(string))
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

variable "execution_role_arn" {
  type    = string
  default = null
}

variable "task_role_arn" {
  type    = string
  default = null
}

variable "health_check_grace_period_seconds" {
  type    = number
  default = null
}

variable "create_execution_role" {
  type    = bool
  default = true
  validation {
    condition     = (var.create_execution_role && var.execution_role_arn == null) || (!var.create_execution_role && var.execution_role_arn != null)
    error_message = "create_execution_role=true OR execution_role_arn (but not both)."
  }
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