# ──────────────────────────────────────────
# OIDC PROVIDER
# Allows GitHub Actions to assume AWS roles
# without storing any long-lived access keys
# ──────────────────────────────────────────
data "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"
}

# ──────────────────────────────────────────
# IAM ROLE — GitHub Actions (CI/CD)
# Least privilege: only what CI needs
# Scoped to your specific repo
# ──────────────────────────────────────────
resource "aws_iam_role" "github_actions" {
  name = "${var.project}-${var.environment}-github-actions-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Federated = data.aws_iam_openid_connect_provider.github.arn
      }
      Action = "sts:AssumeRoleWithWebIdentity"
      Condition = {
      StringLike = {
        "token.actions.githubusercontent.com:sub" = [
          "repo:Aayushsoni09/DevOps-Task-PG-AGI:*",
          "repo:Aayushsoni09/PG-AGI-INFRA:*"
        ]
      }
      StringEquals = {
        "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
      }
    }}]
  })

  tags = var.tags
}

# What GitHub Actions CI is allowed to do
resource "aws_iam_role_policy" "github_actions" {
  name = "${var.project}-${var.environment}-github-actions-policy"
  role = aws_iam_role.github_actions.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "TerraformFullAccess"
        Effect = "Allow"
        Action = [
          # EC2/VPC
          "ec2:*",
          # ECS
          "ecs:*",
          # IAM
          "iam:GetRole",
          "iam:CreateRole",
          "iam:DeleteRole",
          "iam:UpdateRole",
          "iam:AttachRolePolicy",
          "iam:DetachRolePolicy",
          "iam:PutRolePolicy",
          "iam:DeleteRolePolicy",
          "iam:GetRolePolicy",
          "iam:ListRolePolicies",
          "iam:ListAttachedRolePolicies",
          "iam:PassRole",
          "iam:GetOpenIDConnectProvider",
          "iam:CreateOpenIDConnectProvider",
          "iam:DeleteOpenIDConnectProvider",
          "iam:TagOpenIDConnectProvider",
          # CloudWatch Logs
          "logs:*",
          # ELB
          "elasticloadbalancing:*",
          # Auto Scaling
          "application-autoscaling:*",
          # Secrets Manager
          "secretsmanager:*"
        ]
        Resource = "*"
      },
      {
        Sid    = "TerraformState"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = [
          "arn:aws:s3:::${var.tf_state_bucket}",
          "arn:aws:s3:::${var.tf_state_bucket}/*"
        ]
      },
      {
        Sid    = "TerraformLock"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject"
        ]
        Resource = "arn:aws:s3:::${var.tf_state_bucket}/.lock*"
      }
    ]
  })
}

# ──────────────────────────────────────────
# IAM ROLE — ECS Task Execution Role
# Used by ECS agent (not your app) to:
# - Pull Docker images
# - Write logs to CloudWatch
# - Fetch secrets from Secrets Manager
# ──────────────────────────────────────────
resource "aws_iam_role" "ecs_task_execution" {
  name = "${var.project}-${var.environment}-ecs-task-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = var.tags
}

# AWS managed policy — covers ECR pull + CloudWatch logs
resource "aws_iam_role_policy_attachment" "ecs_task_execution" {
  role       = aws_iam_role.ecs_task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Extra policy — allow fetching secrets from Secrets Manager
# (injected as env vars into containers at runtime)
resource "aws_iam_role_policy" "ecs_secrets" {
  name = "${var.project}-${var.environment}-ecs-secrets-policy"
  role = aws_iam_role.ecs_task_execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid    = "SecretsManagerAccess"
      Effect = "Allow"
      Action = [
        "secretsmanager:GetSecretValue"
      ]
      # Scoped to only secrets with your project prefix
      Resource = "arn:aws:secretsmanager:${var.aws_region}:*:secret:${var.project}/${var.environment}/*"
    }]
  })
}

# ──────────────────────────────────────────
# IAM ROLE — ECS Task Role
# Used by your APPLICATION code at runtime
# Only give it what the app actually needs
# Currently: nothing extra (app is stateless)
# ──────────────────────────────────────────
resource "aws_iam_role" "ecs_task" {
  name = "${var.project}-${var.environment}-ecs-task-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = var.tags
}
