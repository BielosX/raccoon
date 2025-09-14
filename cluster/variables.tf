variable "region" {
  type = string
}

variable "availability_zones" {
  type = list(string)
}

variable "cidr" {
  type = string
}

variable "cluster_name" {
  type = string
}

variable "subnet_size" {
  type = number
}