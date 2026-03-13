// variables.tf
variable "project" { type = string }
variable "environment" { type = string }
variable "aws_region" { type = string }
variable "github_org" {
  description = "Your GitHub username or org e.g. monkweb009"
  type        = string
}
variable "github_repo" {
  description = "Your app repo name e.g. pgagi-app"
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
