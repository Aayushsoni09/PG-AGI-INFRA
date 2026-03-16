// variables.tf
variable "github_org" { type = string }
variable "github_repo" { type = string }
variable "backend_image" { type = string }
variable "frontend_image" { type = string }
variable "image_tag" { 
    type = string
 default = "latest"
  }
