# ──────────────────────────────────────────
# VPC
# ──────────────────────────────────────────
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true  # required for ECS tasks to resolve endpoints

  tags = merge(var.tags, {
    Name = "${var.project}-${var.environment}-vpc"
  })
}

# ──────────────────────────────────────────
# INTERNET GATEWAY
# Allows public subnets to reach internet
# ──────────────────────────────────────────
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = merge(var.tags, {
    Name = "${var.project}-${var.environment}-igw"
  })
}

# ──────────────────────────────────────────
# PUBLIC SUBNETS (one per AZ)
# Houses: ALB, NAT Gateway
# ──────────────────────────────────────────
resource "aws_subnet" "public" {
  count = length(var.azs)

  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = var.azs[count.index]
  map_public_ip_on_launch = true  # instances in public subnet get public IP

  tags = merge(var.tags, {
    Name = "${var.project}-${var.environment}-public-${var.azs[count.index]}"
    Tier = "public"
  })
}

# ──────────────────────────────────────────
# PRIVATE SUBNETS (one per AZ)
# Houses: ECS Fargate tasks (frontend + backend)
# NO direct internet access — goes via NAT
# ──────────────────────────────────────────
resource "aws_subnet" "private" {
  count = length(var.azs)

  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.private_subnet_cidrs[count.index]
  availability_zone       = var.azs[count.index]
  map_public_ip_on_launch = false  # private — no public IPs ever

  tags = merge(var.tags, {
    Name = "${var.project}-${var.environment}-private-${var.azs[count.index]}"
    Tier = "private"
  })
}

# ──────────────────────────────────────────
# ELASTIC IP for NAT Gateway
# Static IP address for the NAT
# ──────────────────────────────────────────
resource "aws_eip" "nat" {
  domain = "vpc"

  tags = merge(var.tags, {
    Name = "${var.project}-${var.environment}-nat-eip"
  })

  # EIP needs IGW to exist first
  depends_on = [aws_internet_gateway.main]
}

# ──────────────────────────────────────────
# NAT GATEWAY (single, in first public subnet)
# Allows private subnet tasks to reach internet
# (to pull Docker images from DockerHub, etc.)
# dev/staging: 1 shared NAT (cost saving)
# prod: 1 per AZ (high availability)
# ──────────────────────────────────────────
resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public[0].id  # always in first public subnet

  tags = merge(var.tags, {
    Name = "${var.project}-${var.environment}-nat"
  })

  depends_on = [aws_internet_gateway.main]
}

# ──────────────────────────────────────────
# ROUTE TABLE — PUBLIC
# Routes internet traffic via IGW
# ──────────────────────────────────────────
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = merge(var.tags, {
    Name = "${var.project}-${var.environment}-rt-public"
  })
}

# Associate public route table with all public subnets
resource "aws_route_table_association" "public" {
  count = length(aws_subnet.public)

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# ──────────────────────────────────────────
# ROUTE TABLE — PRIVATE
# Routes outbound traffic via NAT Gateway
# (so ECS tasks can pull images, call APIs)
# ──────────────────────────────────────────
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main.id
  }

  tags = merge(var.tags, {
    Name = "${var.project}-${var.environment}-rt-private"
  })
}

# Associate private route table with all private subnets
resource "aws_route_table_association" "private" {
  count = length(aws_subnet.private)

  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}

# ──────────────────────────────────────────
# SECURITY GROUP — ALB
# What traffic the load balancer accepts
# ──────────────────────────────────────────
resource "aws_security_group" "alb" {
  name        = "${var.project}-${var.environment}-sg-alb"
  description = "Controls traffic to the ALB"
  vpc_id      = aws_vpc.main.id

  # Allow HTTP from anywhere (will redirect to HTTPS in prod)
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTP from internet"
  }

  # Allow HTTPS from anywhere
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTPS from internet"
  }

  # Allow all outbound (to reach ECS tasks)
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "All outbound"
  }

  tags = merge(var.tags, {
    Name = "${var.project}-${var.environment}-sg-alb"
  })
}

# ──────────────────────────────────────────
# SECURITY GROUP — ECS TASKS (Frontend)
# Only accepts traffic FROM the ALB
# NOT from internet directly
# ──────────────────────────────────────────
resource "aws_security_group" "ecs_frontend" {
  name        = "${var.project}-${var.environment}-sg-ecs-frontend"
  description = "Controls traffic to frontend ECS tasks"
  vpc_id      = aws_vpc.main.id

  # Only allow traffic from ALB security group on port 3000
  ingress {
    from_port       = 3000
    to_port         = 3000
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
    description     = "From ALB only"
  }

  # Allow all outbound (to reach backend, DockerHub via NAT)
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "All outbound"
  }

  tags = merge(var.tags, {
    Name = "${var.project}-${var.environment}-sg-ecs-frontend"
  })
}

# ──────────────────────────────────────────
# SECURITY GROUP — ECS TASKS (Backend)
# Only accepts traffic FROM frontend tasks
# Extra isolation layer
# ──────────────────────────────────────────
resource "aws_security_group" "ecs_backend" {
  name        = "${var.project}-${var.environment}-sg-ecs-backend"
  description = "Controls traffic to backend ECS tasks"
  vpc_id      = aws_vpc.main.id

  # Accept from ALB (for direct /api/* routing)
  ingress {
    from_port       = 8000
    to_port         = 8000
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
    description     = "From ALB only"
  }

  # Allow all outbound
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "All outbound"
  }

  tags = merge(var.tags, {
    Name = "${var.project}-${var.environment}-sg-ecs-backend"
  })
}
