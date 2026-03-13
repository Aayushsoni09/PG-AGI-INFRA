# ──────────────────────────────────────────
# APPLICATION LOAD BALANCER
# Sits in public subnets
# Routes traffic to frontend and backend ECS tasks
# ──────────────────────────────────────────
resource "aws_lb" "main" {
  name               = "${var.project}-${var.environment}-alb"
  internal           = false        # public facing
  load_balancer_type = "application"
  security_groups    = [var.alb_security_group_id]
  subnets            = var.public_subnet_ids  # ALB spans public subnets

  # prod only: enable deletion protection
  enable_deletion_protection = var.enable_deletion_protection

  tags = merge(var.tags, {
    Name = "${var.project}-${var.environment}-alb"
  })
}

# ──────────────────────────────────────────
# TARGET GROUP — Frontend
# ALB forwards /* traffic here
# Health check hits Next.js on port 3000
# ──────────────────────────────────────────
resource "aws_lb_target_group" "frontend" {
  name        = "${var.project}-${var.environment}-tg-frontend"
  port        = 3000
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"  # required for Fargate (tasks have IPs, not instance IDs)

  health_check {
    path                = "/"           # Next.js serves / by default
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }

  # Allows tasks to deregister gracefully during deployments
  deregistration_delay = 30

  tags = merge(var.tags, {
    Name = "${var.project}-${var.environment}-tg-frontend"
  })
}

# ──────────────────────────────────────────
# TARGET GROUP — Backend
# ALB forwards /api/* traffic here
# Health check hits FastAPI /api/health
# ──────────────────────────────────────────
resource "aws_lb_target_group" "backend" {
  name        = "${var.project}-${var.environment}-tg-backend"
  port        = 8000
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    path                = "/api/health"
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }

  deregistration_delay = 30

  tags = merge(var.tags, {
    Name = "${var.project}-${var.environment}-tg-backend"
  })
}

# ──────────────────────────────────────────
# LISTENER — HTTP on port 80
# Routes traffic based on path rules
# /api/* → backend target group
# /*     → frontend target group (default)
# ──────────────────────────────────────────
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  # Default action: send to frontend
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.frontend.arn
  }
}

# ──────────────────────────────────────────
# LISTENER RULE — Route /api/* to backend
# Priority 1 = evaluated first
# ──────────────────────────────────────────
resource "aws_lb_listener_rule" "backend_api" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 1

  condition {
    path_pattern {
      values = ["/api/*"]
    }
  }

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.backend.arn
  }
}
