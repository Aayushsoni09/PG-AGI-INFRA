output "frontend_url" {
  description = "GCP frontend URL — visit this to see the app"
  value       = module.cloudrun.frontend_url
}

output "backend_url" {
  description = "GCP backend URL"
  value       = module.cloudrun.backend_url
}

output "workload_identity_provider" {
  description = "Add this to GitHub Actions workflow for GCP OIDC"
  value       = module.iam.workload_identity_provider
}

output "github_actions_service_account" {
  description = "Add this to GitHub Actions workflow for GCP OIDC"
  value       = module.iam.github_actions_service_account
}
