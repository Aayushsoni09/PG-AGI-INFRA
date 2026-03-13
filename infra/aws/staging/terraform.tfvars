vpc_cidr             = "10.1.0.0/16"   # different CIDR from dev — no overlap
azs                  = ["ap-south-1a", "ap-south-1b"]
public_subnet_cidrs  = ["10.1.1.0/24", "10.1.2.0/24"]
private_subnet_cidrs = ["10.1.10.0/24", "10.1.20.0/24"]

github_org  = "monkweb009"
github_repo = "pgagi-app"

tf_state_bucket = "pgagi-tfstate-monkweb009"
tf_lock_table   = "pgagi-tfstate-lock"

frontend_image = "monkweb009/pgagi-frontend"
backend_image  = "monkweb009/pgagi-backend"
image_tag      = "latest"
