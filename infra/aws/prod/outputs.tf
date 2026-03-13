output "alb_dns_name" {
  value = "http://${module.loadbalancer.alb_dns_name}"
}
output "github_actions_role_arn" {
  value = module.iam.github_actions_role_arn
}
output "ecs_cluster_name" {
  value = module.compute.ecs_cluster_name
}
output "frontend_service_name" {
  value = module.compute.frontend_service_name
}
output "backend_service_name" {
  value = module.compute.backend_service_name
}
