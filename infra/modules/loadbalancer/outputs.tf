output "alb_dns_name" {
  description = "DNS name of the ALB — this is your NEXT_PUBLIC_API_URL base"
  value       = aws_lb.main.dns_name
}

output "alb_arn" {
  value = aws_lb.main.arn
}

output "frontend_target_group_arn" {
  value = aws_lb_target_group.frontend.arn
}

output "backend_target_group_arn" {
  value = aws_lb_target_group.backend.arn
}

output "http_listener_arn" {
  value = aws_lb_listener.http.arn
}
