
data "aws_caller_identity" "current" {}
# ECS CLUSTER
# Logical grouping of ECS services/tasks
# Fargate = no EC2 instances to manage
# ──────────────────────────────────────────
resource "aws_ecs_cluster" "main" {
  name = "${var.project}-${var.environment}-cluster"

  setting {
    name  = "containerInsights"
    value = var.enable_container_insights ? "enabled" : "disabled"
    # dev: disabled (costs extra), prod: enabled
  }

  tags = merge(var.tags, {
    Name = "${var.project}-${var.environment}-cluster"
  })
}

# ──────────────────────────────────────────
# CLOUDWATCH LOG GROUPS
# Where container stdout/stderr goes
# ──────────────────────────────────────────
resource "aws_cloudwatch_log_group" "frontend" {
  name              = "/ecs/${var.project}/${var.environment}/frontend"
  retention_in_days = var.log_retention_days  # dev: 7, prod: 30

  tags = var.tags
}

resource "aws_cloudwatch_log_group" "backend" {
  name              = "/ecs/${var.project}/${var.environment}/backend"
  retention_in_days = var.log_retention_days

  tags = var.tags
}

# ──────────────────────────────────────────
# TASK DEFINITION — Frontend
# Defines what container to run + resources
# Think of it as a "blueprint" for the container
# ──────────────────────────────────────────
resource "aws_ecs_task_definition" "frontend" {
  family                   = "${var.project}-${var.environment}-frontend"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"  # required for Fargate
  cpu                      = var.frontend_cpu
  memory                   = var.frontend_memory
  execution_role_arn       = var.ecs_task_execution_role_arn  # pulls image, writes logs
  task_role_arn            = var.ecs_task_role_arn            # app permissions at runtime
  lifecycle {
    ignore_changes = [container_definitions]
  }
  container_definitions = jsonencode([{
    name      = "frontend"
    image     = "${var.frontend_image}:${var.image_tag}"
    essential = true
    portMappings = [{
      containerPort = 3000
      protocol      = "tcp"
    }]

    environment = [
      {
        name  = "NEXT_PUBLIC_API_URL"
        # Points to ALB DNS — browser calls go here
        value = "http://${var.alb_dns_name}"
      }
    ]

    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = aws_cloudwatch_log_group.frontend.name
        "awslogs-region"        = var.aws_region
        "awslogs-stream-prefix" = "frontend"
      }
    }

    # Health check inside the container
    healthCheck = {
      command     = ["CMD-SHELL", "curl -f http://localhost:3000/ || exit 1"]
      interval    = 30
      timeout     = 5
      retries     = 3
      startPeriod = 60  # give Next.js time to start up
    }
  }])

  tags = var.tags
}

# ──────────────────────────────────────────
# TASK DEFINITION — Backend
# ──────────────────────────────────────────
resource "aws_ecs_task_definition" "backend" {
  family                   = "${var.project}-${var.environment}-backend"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.backend_cpu
  memory                   = var.backend_memory
  execution_role_arn       = var.ecs_task_execution_role_arn
  task_role_arn            = var.ecs_task_role_arn
  lifecycle {
    ignore_changes = [container_definitions]
  }
  container_definitions = jsonencode([{
    name      = "backend"
    image     = "${var.backend_image}:${var.image_tag}"
    essential = true

    portMappings = [{
      containerPort = 8000
      protocol      = "tcp"
    }]

    # No hardcoded secrets here — pulled from Secrets Manager
    # via secrets block (injected as env vars at runtime)
    environment = [
      {
        name  = "ENVIRONMENT"
        value = var.environment
      }
    ]

    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = aws_cloudwatch_log_group.backend.name
        "awslogs-region"        = var.aws_region
        "awslogs-stream-prefix" = "backend"
      }
    }

    healthCheck = {
      command     = ["CMD-SHELL", "curl -f http://localhost:8000/api/health || exit 1"]
      interval    = 30
      timeout     = 5
      retries     = 3
      startPeriod = 30
    }
  }])

  tags = var.tags
}

# ──────────────────────────────────────────
# ECS SERVICE — Frontend
# Keeps N tasks running, connects to ALB
# Handles rolling deployments automatically
# ──────────────────────────────────────────
resource "aws_ecs_service" "frontend" {
  name            = "${var.project}-${var.environment}-frontend"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.frontend.arn
  desired_count   = var.frontend_desired_count
  launch_type     = "FARGATE"

  # Rolling deployment config
  # dev: faster deploys (accept brief unavailability)
  # prod: zero downtime (keep 100% capacity during deploy)
  deployment_minimum_healthy_percent = var.deployment_min_healthy_percent
  deployment_maximum_percent         = var.deployment_max_percent

  network_configuration {
    subnets          = var.private_subnet_ids   # tasks in private subnets
    security_groups  = [var.ecs_frontend_security_group_id]
    assign_public_ip = false                    # private — no public IPs
  }

  load_balancer {
    target_group_arn = var.frontend_target_group_arn
    container_name   = "frontend"
    container_port   = 3000
  }

  # Ignore task_definition changes from outside Terraform
  # (CI will update task definitions directly)
  lifecycle {
    ignore_changes = [task_definition, desired_count]
  }

  depends_on = [var.http_listener_arn]

  tags = var.tags
}

# ──────────────────────────────────────────
# ECS SERVICE — Backend
# ──────────────────────────────────────────
resource "aws_ecs_service" "backend" {
  name            = "${var.project}-${var.environment}-backend"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.backend.arn
  desired_count   = var.backend_desired_count
  launch_type     = "FARGATE"

  deployment_minimum_healthy_percent = var.deployment_min_healthy_percent
  deployment_maximum_percent         = var.deployment_max_percent

  network_configuration {
    subnets          = var.private_subnet_ids
    security_groups  = [var.ecs_backend_security_group_id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = var.backend_target_group_arn
    container_name   = "backend"
    container_port   = 8000
  }

  lifecycle {
    ignore_changes = [task_definition, desired_count]
  }

  depends_on = [var.http_listener_arn]

  tags = var.tags
}

# ──────────────────────────────────────────
# AUTO SCALING — Backend
# Scale based on CPU usage
# dev: disabled (min=max=1)
# staging/prod: enabled
# ──────────────────────────────────────────
resource "aws_appautoscaling_target" "backend" {
  count = var.enable_autoscaling ? 1 : 0

  max_capacity       = var.backend_max_count
  min_capacity       = var.backend_desired_count
  resource_id        = "service/${aws_ecs_cluster.main.name}/${aws_ecs_service.backend.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

resource "aws_appautoscaling_policy" "backend_cpu" {
  count = var.enable_autoscaling ? 1 : 0

  name               = "${var.project}-${var.environment}-backend-cpu-scaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.backend[0].resource_id
  scalable_dimension = aws_appautoscaling_target.backend[0].scalable_dimension
  service_namespace  = aws_appautoscaling_target.backend[0].service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    target_value       = 70.0  # scale up when CPU > 70%
    scale_in_cooldown  = 300   # wait 5 min before scaling in
    scale_out_cooldown = 60    # scale out quickly when needed
  }
}
