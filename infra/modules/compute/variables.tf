// variables.tf
variable "project" { type = string }
variable "environment" { type = string }
variable "aws_region" { type = string }
variable "vpc_id" { type = string }
variable "private_subnet_ids" { type = list(string) }
variable "ecs_frontend_security_group_id" { type = string }
variable "ecs_backend_security_group_id" { type = string }
variable "ecs_task_execution_role_arn" { type = string }
variable "ecs_task_role_arn" { type = string }
variable "frontend_target_group_arn" { type = string }
variable "backend_target_group_arn" { type = string }
variable "http_listener_arn" { type = string }
variable "alb_dns_name" { type = string }

variable "frontend_image" {
  description = "DockerHub image for frontend e.g. monkweb009/pgagi-frontend"
  type        = string
}
variable "backend_image" {
  description = "DockerHub image for backend e.g. monkweb009/pgagi-backend"
  type        = string
}
variable "image_tag" {
  description = "Docker image tag to deploy"
  type        = string
  default     = "latest"
}

# Resource sizing — differs per environment
variable "frontend_cpu" { 
    type = number
    default = 256 
  }
variable "frontend_memory" { 
  type = number 
  default = 512 
  }
variable "backend_cpu" { 
  type = number 
  default = 256 
  }
variable "backend_memory" { 
  type = number
 default = 512 
 }

# Task counts — differs per environment
variable "frontend_desired_count" { 
  type = number
   default = 1 
   }
variable "backend_desired_count" { 
  type = number
   default = 1 
   }
variable "backend_max_count" { 
  type = number
   default = 3 
   }

# Deployment config
variable "deployment_min_healthy_percent" { 
  type = number
   default = 50 
   }
variable "deployment_max_percent" { 
  type = number
   default = 200 
   }

# Feature flags
variable "enable_autoscaling" { 
  type = bool
   default = false 
   }
variable "enable_container_insights" { 
  type = bool 
  default = false 
  }
variable "log_retention_days" { 
  type = number
   default = 7 
   }

variable "tags" { 
  type = map(string)
   default = {} 
   }
