// variables.tf
variable "project_id" { type = string }
variable "environment" { type = string }
variable "region" { type = string }

variable "subnet_cidr" {
  type    = string
  default = "10.0.0.0/24"
}

variable "connector_cidr" {
  description = "Must not overlap with subnet_cidr — used by VPC connector"
  type        = string
  default     = "10.8.0.0/28"
}

variable "connector_max_instances" {
  type    = number
  default = 3
}

variable "connector_machine_type" {
  type    = string
  default = "e2-micro"
}
