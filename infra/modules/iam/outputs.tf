output "github_actions_role_arn" {
  description = "ARN of the GitHub Actions IAM role — put this in GitHub Actions workflow"
  value       = aws_iam_role.github_actions.arn
}

output "ecs_task_execution_role_arn" {
  description = "ARN of the ECS task execution role"
  value       = aws_iam_role.ecs_task_execution.arn
}

output "ecs_task_role_arn" {
  description = "ARN of the ECS task role (used by app at runtime)"
  value       = aws_iam_role.ecs_task.arn
}
