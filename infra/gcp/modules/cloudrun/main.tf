# ──────────────────────────────────────────
# CLOUD RUN SERVICE — Backend
# Serverless container — scales to 0 when idle
# Key difference from AWS ECS Fargate:
# ECS always has min 1 task running
# Cloud Run can scale to zero (no cost when idle)
# ──────────────────────────────────────────
resource "google_cloud_run_v2_service" "backend" {
  name     = "${var.project_id}-${var.environment}-backend"
  location = var.region
  project  = var.project_id

  # dev: allow direct access for testing
  # prod: internal only, traffic via load balancer
  ingress = var.environment == "dev" ? "INGRESS_TRAFFIC_ALL" : "INGRESS_TRAFFIC_INTERNAL_LOAD_BALANCER"

  template {
    service_account = var.cloudrun_service_account

    # Connect to VPC via serverless connector
    vpc_access {
      connector = var.vpc_connector_id
      egress    = "PRIVATE_RANGES_ONLY"
    }

    scaling {
      min_instance_count = var.backend_min_instances  # dev: 0, prod: 1
      max_instance_count = var.backend_max_instances  # dev: 2, prod: 10
    }

    containers {
      image = "${var.backend_image}:${var.image_tag}"

      ports {
        container_port = 8000
      }

      resources {
        limits = {
          cpu    = var.backend_cpu     # dev: "1", prod: "2"
          memory = var.backend_memory  # dev: "512Mi", prod: "1Gi"
        }
        # Only allocate CPU during request processing
        # Key cost saving vs always-on ECS
        cpu_idle = var.environment == "prod" ? false : true
      }

      env {
        name  = "ENVIRONMENT"
        value = var.environment
      }

      # Health check
      liveness_probe {
        http_get {
          path = "/api/health"
          port = 8000
        }
        initial_delay_seconds = 10
        period_seconds        = 30
        failure_threshold     = 3
      }

      startup_probe {
        http_get {
          path = "/api/health"
          port = 8000
        }
        initial_delay_seconds = 5
        period_seconds        = 5
        failure_threshold     = 10
      }
    }
  }

  traffic {
    type    = "TRAFFIC_TARGET_ALLOCATION_TYPE_LATEST"
    percent = 100
  }
}

# ──────────────────────────────────────────
# CLOUD RUN SERVICE — Frontend
# ──────────────────────────────────────────
resource "google_cloud_run_v2_service" "frontend" {
  name     = "${var.project_id}-${var.environment}-frontend"
  location = var.region
  project  = var.project_id

  ingress = "INGRESS_TRAFFIC_ALL"

  template {
    service_account = var.cloudrun_service_account

    vpc_access {
      connector = var.vpc_connector_id
      egress    = "PRIVATE_RANGES_ONLY"
    }

    scaling {
      min_instance_count = var.frontend_min_instances
      max_instance_count = var.frontend_max_instances
    }

    containers {
      image = "${var.frontend_image}:${var.image_tag}"

      ports {
        container_port = 3000
      }

      resources {
        limits = {
          cpu    = var.frontend_cpu
          memory = var.frontend_memory
        }
        cpu_idle = var.environment == "prod" ? false : true
      }

      env {
        name  = "NEXT_PUBLIC_API_URL"
        value = var.backend_url
      }

      startup_probe {
        http_get {
          path = "/"
          port = 3000
        }
        initial_delay_seconds = 10
        period_seconds        = 5
        failure_threshold     = 10
      }
    }
  }

  traffic {
    type    = "TRAFFIC_TARGET_ALLOCATION_TYPE_LATEST"
    percent = 100
  }
}

# ──────────────────────────────────────────
# IAM — Allow public access to Cloud Run
# Makes services publicly accessible via
# the load balancer
# ──────────────────────────────────────────
resource "google_cloud_run_v2_service_iam_member" "backend_public" {
  project  = var.project_id
  location = var.region
  name     = google_cloud_run_v2_service.backend.name
  role     = "roles/run.invoker"
  member   = "allUsers"
}

resource "google_cloud_run_v2_service_iam_member" "frontend_public" {
  project  = var.project_id
  location = var.region
  name     = google_cloud_run_v2_service.frontend.name
  role     = "roles/run.invoker"
  member   = "allUsers"
}
