# These outputs are consumed by other modules
# e.g. compute module needs subnet IDs to place ECS tasks
# loadbalancer module needs subnet IDs to place ALB

output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.main.id
}

output "public_subnet_ids" {
  description = "IDs of public subnets — used by ALB"
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "IDs of private subnets — used by ECS tasks"
  value       = aws_subnet.private[*].id
}

output "alb_security_group_id" {
  description = "Security group ID for the ALB"
  value       = aws_security_group.alb.id
}

output "ecs_frontend_security_group_id" {
  description = "Security group ID for frontend ECS tasks"
  value       = aws_security_group.ecs_frontend.id
}

output "ecs_backend_security_group_id" {
  description = "Security group ID for backend ECS tasks"
  value       = aws_security_group.ecs_backend.id
}

output "nat_gateway_ip" {
  description = "Public IP of the NAT Gateway (useful for whitelisting)"
  value       = aws_eip.nat.public_ip
}
