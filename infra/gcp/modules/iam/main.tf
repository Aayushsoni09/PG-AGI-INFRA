locals {
  workload_identity_pool_name     = "projects/262940582686/locations/global/workloadIdentityPools/github-pool"
  workload_identity_provider_name = "projects/262940582686/locations/global/workloadIdentityPools/github-pool/providers/github-provider"
}

# ──────────────────────────────────────────
# SERVICE ACCOUNT — GitHub Actions CI/CD
# ──────────────────────────────────────────
resource "google_service_account" "github_actions" {
  account_id   = "github-actions-${var.environment}"
  display_name = "GitHub Actions Service Account (${var.environment})"
  project      = var.project_id
}

# Allow GitHub Actions to impersonate this service account via Workload Identity
resource "google_service_account_iam_member" "github_workload_identity" {
  service_account_id = google_service_account.github_actions.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${local.workload_identity_pool_name}/attribute.repository/${var.github_org}/${var.github_repo}"
}

resource "google_project_iam_member" "github_actions_cloudrun" {
  project = var.project_id
  role    = "roles/run.admin"
  member  = "serviceAccount:${google_service_account.github_actions.email}"
}

resource "google_project_iam_member" "github_actions_artifactregistry" {
  project = var.project_id
  role    = "roles/artifactregistry.writer"
  member  = "serviceAccount:${google_service_account.github_actions.email}"
}

resource "google_project_iam_member" "github_actions_sa_user" {
  project = var.project_id
  role    = "roles/iam.serviceAccountUser"
  member  = "serviceAccount:${google_service_account.github_actions.email}"
}

resource "google_project_iam_member" "github_actions_storage" {
  project = var.project_id
  role    = "roles/storage.admin"
  member  = "serviceAccount:${google_service_account.github_actions.email}"
}

# ──────────────────────────────────────────
# SERVICE ACCOUNT — Cloud Run Runtime
# ──────────────────────────────────────────
resource "google_service_account" "cloudrun" {
  account_id   = "cloudrun-${var.environment}"
  display_name = "Cloud Run Service Account (${var.environment})"
  project      = var.project_id
}

resource "google_project_iam_member" "cloudrun_artifactregistry" {
  project = var.project_id
  role    = "roles/artifactregistry.reader"
  member  = "serviceAccount:${google_service_account.cloudrun.email}"
}

resource "google_project_iam_member" "cloudrun_secretmanager" {
  project = var.project_id
  role    = "roles/secretmanager.secretAccessor"
  member  = "serviceAccount:${google_service_account.cloudrun.email}"
}
