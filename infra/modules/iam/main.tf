# ──────────────────────────────────────────
# OIDC PROVIDER
# Allows GitHub Actions to assume AWS roles
# without storing any long-lived access keys
# ──────────────────────────────────────────
resource "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"

  client_id_list = ["sts.amazonaws.com"]

  # GitHub's OIDC thumbprint — stable, doesn't change often
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]

  tags = var.tags
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
        Federated = aws_iam_openid_connect_provider.github.arn
      }
      Action = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringLike = {
          # Scoped to YOUR repo only — change this to your repo
          "token.actions.githubusercontent.com:sub" = "repo:${var.github_org}/${var.github_repo}:*"
        }
        StringEquals = {
          "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
        }
      }
    }]
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
        # ECS — update services with new image
        Sid    = "ECSAccess"
        Effect = "Allow"
        Action = [
          "ecs:UpdateService",
          "ecs:DescribeServices",
          "ecs:DescribeTaskDefinition",
          "ecs:RegisterTaskDefinition",
          "ecs:ListTasks",
          "ecs:DescribeTasks"
        ]
        Resource = "*"
      },
      {
        # Pass role to ECS task (needed for task definition updates)
        Sid    = "PassRole"
        Effect = "Allow"
        Action = "iam:PassRole"
        Resource = [
          aws_iam_role.ecs_task_execution.arn,
          aws_iam_role.ecs_task.arn
        ]
      },
      {
        # Terraform state — read/write S3
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
        # Terraform state locking — DynamoDB
        Sid    = "TerraformLock"
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:DeleteItem"
        ]
        Resource = "arn:aws:dynamodb:${var.aws_region}:*:table/${var.tf_lock_table}"
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
