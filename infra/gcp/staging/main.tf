locals {
  project_id  = "pgagi-task"
  environment = "staging"
  region      = "asia-south1"
}

module "networking" {
  source      = "../modules/networking"
  project_id  = local.project_id
  environment = local.environment
  region      = local.region

  subnet_cidr    = "10.1.0.0/24"
  connector_cidr = "10.9.0.0/28"

  connector_max_instances = 5
  connector_machine_type  = "e2-micro"
}

module "iam" {
  source      = "../modules/iam"
  project_id  = local.project_id
  environment = local.environment
  github_org  = var.github_org
  github_repo = var.github_repo
}

module "cloudrun" {
  source      = "../modules/cloudrun"
  project_id  = local.project_id
  environment = local.environment
  region      = local.region

  vpc_connector_id         = module.networking.connector_id
  cloudrun_service_account = module.iam.cloudrun_service_account

  backend_image  = var.backend_image
  frontend_image = var.frontend_image
  image_tag      = var.image_tag
  backend_url    = module.cloudrun.backend_url

  # staging: min 1 instance — no cold starts
  backend_min_instances  = 1
  backend_max_instances  = 3
  frontend_min_instances = 1
  frontend_max_instances = 3

  backend_cpu     = "1"
  backend_memory  = "1Gi"
  frontend_cpu    = "1"
  frontend_memory = "512Mi"
}
