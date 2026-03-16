locals {
  project_id  = "pgagi-task"
  environment = "dev"
  region      = "asia-south1"
}

module "networking" {
  source      = "../modules/networking"
  project_id  = local.project_id
  environment = local.environment
  region      = local.region

  subnet_cidr    = "10.0.0.0/24"
  connector_cidr = "10.8.0.0/28"

  # dev: minimal connector size
  connector_max_instances = 3
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

  # The frontend needs to know where the backend is
  # For GCP we use the Cloud Run backend URL directly
  backend_url = module.cloudrun.backend_url

  # dev: scale to zero (free when idle)
  backend_min_instances  = 0
  backend_max_instances  = 2
  frontend_min_instances = 0
  frontend_max_instances = 2

  # dev: small resources
  backend_cpu     = "1"
  backend_memory  = "512Mi"
  frontend_cpu    = "1"
  frontend_memory = "512Mi"
}
