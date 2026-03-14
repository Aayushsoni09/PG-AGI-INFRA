// variables.tf
variable "project" { type = string }
variable "environment" { type = string }
variable "aws_region" { type = string }
variable "github_org" {
  description = "GitHub username"
  type        = string
}
variable "github_repo" {
  description = "app repo name"
  type        = string
}
variable "tf_state_bucket" {
  description = "S3 bucket name for Terraform state"
  type        = string
}
variable "tf_lock_table" {
  description = "DynamoDB table name for Terraform state locking"
  type        = string
}
variable "tags" {
  type    = map(string)
  default = {}
}
