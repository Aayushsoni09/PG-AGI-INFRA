// variables.tf
variable "project" { type = string }
variable "environment" { type = string }
variable "vpc_id" { type = string }
variable "public_subnet_ids" { type = list(string) }
variable "alb_security_group_id" { type = string }
variable "enable_deletion_protection" {
  type    = bool
  default = false  # true in prod
}
variable "tags" {
  type    = map(string)
  default = {}
}
