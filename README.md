# pgagi-infra

Infrastructure as Code for the PG-AGI DevOps assignment.
Manages AWS (ECS Fargate) and GCP (Cloud Run) deployments across dev / staging / prod.

---

## Architecture

```
Internet
   ↓
CloudFront (CDN)
   ↓
ALB (public subnets)
   ├── /* → Frontend ECS Task (private subnet, port 3000)
   └── /api/* → Backend ECS Task (private subnet, port 8000)
                      ↓
               NAT Gateway (outbound only — DockerHub image pulls)
```

### Environment Differences

| Setting                        | dev     | staging  | prod     |
|-------------------------------|---------|----------|----------|
| Frontend CPU / Memory          | 256/512 | 256/512  | 512/1024 |
| Backend CPU / Memory           | 256/512 | 512/1024 | 1024/2048|
| Min tasks (frontend + backend) | 1 + 1   | 1 + 1    | 2 + 2    |
| Autoscaling                    | ❌      | ✅        | ✅        |
| Deletion protection            | ❌      | ✅        | ✅        |
| Container insights             | ❌      | ✅        | ✅        |
| Log retention                  | 7 days  | 14 days  | 30 days  |
| Deploy downtime                | allowed | zero     | zero     |

---

## State Management

All Terraform state is stored remotely in S3 with DynamoDB locking.

| Environment | State Key                        |
|-------------|----------------------------------|
| dev         | `aws/dev/terraform.tfstate`      |
| staging     | `aws/staging/terraform.tfstate`  |
| prod        | `aws/prod/terraform.tfstate`     |

Each environment has fully isolated state — a broken dev state cannot affect prod.

---

## First-Time Setup

### 1. Prerequisites
```bash
# Install required tools
brew install terraform awscli   # macOS
# or use apt/choco for Linux/Windows

# Configure AWS credentials (one-time, local only)
aws configure
# Enter your Access Key ID, Secret, region: ap-south-1
```

### 2. Bootstrap state backend (run ONCE)
```bash
chmod +x bootstrap.sh
./bootstrap.sh
```
This creates the S3 bucket and DynamoDB table for Terraform state.
These are intentionally NOT managed by Terraform (chicken-and-egg problem).

### 3. Deploy dev environment
```bash
cd infra/aws/dev
terraform init
terraform plan
terraform apply
```

After apply, note the outputs:
```
alb_dns_name              = "http://pgagi-dev-alb-xxxx.ap-south-1.elb.amazonaws.com"
github_actions_role_arn   = "arn:aws:iam::ACCOUNT:role/pgagi-dev-github-actions-role"
```

### 4. Add GitHub secrets to pgagi-app repo

Go to: pgagi-app repo → Settings → Secrets and variables → Actions

| Secret name                    | Value                                      |
|--------------------------------|--------------------------------------------|
| `AWS_GITHUB_ACTIONS_ROLE_ARN`  | output from `terraform output` above       |
| `NEXT_PUBLIC_API_URL`          | ALB DNS name from above                    |
| `DOCKERHUB_USERNAME`           | `monkweb009`                               |
| `DOCKERHUB_TOKEN`              | DockerHub access token (not password)      |

### 5. Add GitHub Environments (for approval gates)
Go to: pgagi-infra repo → Settings → Environments

- Create `dev` — no protection rules (auto-deploys)
- Create `staging` — add yourself as required reviewer
- Create `prod` — add required reviewer + set wait timer (e.g. 5 min)

---

## CI/CD Flow

```
Push to main (infra change)
        ↓
terraform plan (all envs) — shown as PR comment
        ↓
Merge to main
        ↓
Auto-apply dev
        ↓
Manual approval → apply staging
        ↓
Manual approval → apply prod
```

---

## Deploying a New Image Version

When CI pushes a new Docker image, update the ECS service:
```bash
# Done automatically by CI — but manually:
aws ecs update-service \
  --cluster pgagi-dev-cluster \
  --service pgagi-dev-backend \
  --force-new-deployment \
  --region ap-south-1
```

---

## Rollback

```bash
# Roll back to previous task definition revision
aws ecs update-service \
  --cluster pgagi-prod-cluster \
  --service pgagi-prod-backend \
  --task-definition pgagi-prod-backend:PREVIOUS_REVISION \
  --region ap-south-1
```

---

## Destroy an environment (dev only — never prod without extreme care)

```bash
cd infra/aws/dev
terraform destroy
```
