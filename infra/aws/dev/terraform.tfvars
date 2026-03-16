# ── Network ──────────────────────────────
vpc_cidr = "10.0.0.0/16"

# ap-south-1a and ap-south-1b
azs = ["ap-south-1a", "ap-south-1b"]

# Public subnets — ALB lives here
public_subnet_cidrs = ["10.0.1.0/24", "10.0.2.0/24"]

# Private subnets — ECS tasks live here
private_subnet_cidrs = ["10.0.10.0/24", "10.0.20.0/24"]

# ── GitHub OIDC ───────────────────────────
github_org  = "Aayushsoni09"
github_repo = "DevOps-Task-PG-AGI"        # your application repo name

# ── Terraform State ───────────────────────
tf_state_bucket = "pgagi-tfstate-monkweb009"
tf_lock_table   = "pgagi-tfstate-lock"

# ── Images ────────────────────────────────
frontend_image = "381491835701.dkr.ecr.ap-south-1.amazonaws.com/pgagi-frontend"
backend_image  = "381491835701.dkr.ecr.ap-south-1.amazonaws.com/pgagi-backend"
image_tag      = "latest"     # CI will override this with git SHA
