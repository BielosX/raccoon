variable "name" {
  type = string
}

variable "cluster_name" {
  type = string
}

variable "container_definitions" {
  type = list(object({
    name           = string
    environment    = map(string)
    container_port = number
    essential      = bool
    privileged     = bool
    image          = string
    user           = string
  }))
}

variable "load_balancers" {
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