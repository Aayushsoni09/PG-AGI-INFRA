// variables.tf
variable "vpc_cidr" { type = string }
variable "azs" { type = list(string) }
variable "public_subnet_cidrs" { type = list(string) }
variable "private_subnet_cidrs" { type = list(string) }
variable "github_org" { type = string }
variable "github_repo" { type = string }
variable "tf_state_bucket" { type = string }
variable "tf_lock_table" { type = string }
variable "frontend_image" { type = string }
variable "backend_image" { type = string }
variable "image_tag" { 
    type = string 
    default = "latest" 
    }
