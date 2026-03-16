output "workload_identity_provider" {
  description = "Full provider name — use in GitHub Actions workflow"
  value = local.workload_identity_provider_name
}

output "github_actions_service_account" {
  description = "Service account email for GitHub Actions"
  value       = google_service_account.github_actions.email
}

output "cloudrun_service_account" {
  description = "Service account email for Cloud Run runtime"
  value       = google_service_account.cloudrun.email
}
