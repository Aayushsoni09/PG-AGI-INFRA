locals {
  project     = "pgagi"
  environment = "dev"
  aws_region  = "ap-south-1"

  common_tags = {
    Project     = local.project
    Environment = local.environment
    ManagedBy   = "terraform"
    Repo        = "pgagi-infra"
  }
}

# ──────────────────────────────────────────
# NETWORKING
# ──────────────────────────────────────────
module "networking" {
  source = "../../modules/networking"

  project     = local.project
  environment = local.environment

  vpc_cidr = var.vpc_cidr
  azs      = var.azs

  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs

  tags = local.common_tags
}

# ──────────────────────────────────────────
# IAM (OIDC + roles)
# ──────────────────────────────────────────
module "iam" {
  source = "../../modules/iam"

  project     = local.project
  environment = local.environment
  aws_region  = local.aws_region

  github_org  = var.github_org
  github_repo = var.github_repo

  tf_state_bucket = var.tf_state_bucket
  tf_lock_table   = var.tf_lock_table

  tags = local.common_tags
}

# ──────────────────────────────────────────
# LOAD BALANCER
# ──────────────────────────────────────────
module "loadbalancer" {
  source = "../../modules/loadbalancer"

  project     = local.project
  environment = local.environment

  vpc_id                     = module.networking.vpc_id
  public_subnet_ids          = module.networking.public_subnet_ids
  alb_security_group_id      = module.networking.alb_security_group_id
  enable_deletion_protection = false  # dev: no deletion protection

  tags = local.common_tags
}

# ──────────────────────────────────────────
# COMPUTE (ECS Fargate)
# dev: smallest sizes, no autoscaling
# ──────────────────────────────────────────
module "compute" {
  source = "../../modules/compute"

  project     = local.project
  environment = local.environment
  aws_region  = local.aws_region

  # Networking
  vpc_id             = module.networking.vpc_id
  private_subnet_ids = module.networking.private_subnet_ids

  # Security groups
  ecs_frontend_security_group_id = module.networking.ecs_frontend_security_group_id
  ecs_backend_security_group_id  = module.networking.ecs_backend_security_group_id

  # IAM roles
  ecs_task_execution_role_arn = module.iam.ecs_task_execution_role_arn
  ecs_task_role_arn           = module.iam.ecs_task_role_arn

  # Load balancer
  frontend_target_group_arn = module.loadbalancer.frontend_target_group_arn
  backend_target_group_arn  = module.loadbalancer.backend_target_group_arn
  http_listener_arn         = module.loadbalancer.http_listener_arn
  alb_dns_name              = module.loadbalancer.alb_dns_name

  # Images
  frontend_image = var.frontend_image
  backend_image  = var.backend_image
  image_tag      = var.image_tag

  # dev: small resources
  frontend_cpu    = 256
  frontend_memory = 512
  backend_cpu     = 256
  backend_memory  = 512

  # dev: 1 task each, no autoscaling
  frontend_desired_count = 1
  backend_desired_count  = 1
  backend_max_count      = 1
  enable_autoscaling     = false

  # dev: faster deploys (brief downtime acceptable)
  deployment_min_healthy_percent = 0
  deployment_max_percent         = 200

  # dev: container insights off (saves cost), short log retention
  enable_container_insights = false
  log_retention_days        = 7

  tags = local.common_tags
}
