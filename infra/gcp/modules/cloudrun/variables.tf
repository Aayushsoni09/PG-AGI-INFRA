// variables.tf
variable "project_id" { type = string }
variable "environment" { type = string }
variable "region" { type = string }
variable "vpc_connector_id" { type = string }
variable "cloudrun_service_account" { type = string }

variable "backend_image" { type = string }
variable "frontend_image" { type = string }
variable "image_tag" { 
    type = string
 default = "latest"
  }
variable "backend_url" { type = string }

variable "backend_cpu" { 
    type = string
    default = "1" 
 }
variable "backend_memory" { 
    type = string
 default = "512Mi"
  }
variable "frontend_cpu" { 
    type = string
 default = "1" 
 }
variable "frontend_memory" { 
    type = string
 default = "512Mi" 
 }

variable "backend_min_instances" { 
    type = number
 default = 0 
 }
variable "backend_max_instances" { 
    type = number
 default = 2 
 }
variable "frontend_min_instances" { 
    type = number 
    default = 0 
    }
variable "frontend_max_instances" { 
    type = number
 default = 2 
 }
