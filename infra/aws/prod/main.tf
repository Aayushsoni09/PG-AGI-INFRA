locals {
  project     = "pgagi"
  environment = "prod"
  aws_region  = "ap-south-1"

  common_tags = {
    Project     = local.project
    Environment = local.environment
    ManagedBy   = "terraform"
    Repo        = "pgagi-infra"
  }
}

module "networking" {
  source               = "../../modules/networking"
  project              = local.project
  environment          = local.environment
  vpc_cidr             = var.vpc_cidr
  azs                  = var.azs
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
  tags                 = local.common_tags
}

module "iam" {
  source          = "../../modules/iam"
  project         = local.project
  environment     = local.environment
  aws_region      = local.aws_region
  github_org      = var.github_org
  github_repo     = var.github_repo
  tf_state_bucket = var.tf_state_bucket
  tf_lock_table   = var.tf_lock_table
  tags            = local.common_tags
}

module "loadbalancer" {
  source                     = "../../modules/loadbalancer"
  project                    = local.project
  environment                = local.environment
  vpc_id                     = module.networking.vpc_id
  public_subnet_ids          = module.networking.public_subnet_ids
  alb_security_group_id      = module.networking.alb_security_group_id
  enable_deletion_protection = false  
  tags                       = local.common_tags
}

module "compute" {
  source = "../../modules/compute"

  project     = local.project
  environment = local.environment
  aws_region  = local.aws_region

  vpc_id             = module.networking.vpc_id
  private_subnet_ids = module.networking.private_subnet_ids

  ecs_frontend_security_group_id = module.networking.ecs_frontend_security_group_id
  ecs_backend_security_group_id  = module.networking.ecs_backend_security_group_id

  ecs_task_execution_role_arn = module.iam.ecs_task_execution_role_arn
  ecs_task_role_arn           = module.iam.ecs_task_role_arn

  frontend_target_group_arn = module.loadbalancer.frontend_target_group_arn
  backend_target_group_arn  = module.loadbalancer.backend_target_group_arn
  http_listener_arn         = module.loadbalancer.http_listener_arn
  alb_dns_name              = module.loadbalancer.alb_dns_name

  frontend_image = var.frontend_image
  backend_image  = var.backend_image
  image_tag      = var.image_tag

  # prod: larger resources
  frontend_cpu    = 512
  frontend_memory = 1024
  backend_cpu     = 1024
  backend_memory  = 2048

  # prod: 2 tasks minimum for HA across AZs, autoscaling up to 5
  frontend_desired_count = 2
  backend_desired_count  = 2
  backend_max_count      = 5
  enable_autoscaling     = true

  # prod: zero downtime — always 100% capacity during deploys
  deployment_min_healthy_percent = 100
  deployment_max_percent         = 200

  # prod: full observability, 30 day log retention
  enable_container_insights = true
  log_retention_days        = 30

  tags = local.common_tags
}
