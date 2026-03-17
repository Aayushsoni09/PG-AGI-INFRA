# DevOps Assignment — PG-AGI

A full-stack application deployed across AWS and GCP with complete CI/CD, security scanning, and Infrastructure as Code.

---

## Live URLs

### AWS (ECS Fargate — ap-south-1 Mumbai)

| Environment | Frontend | Backend Health |
|---|---|---|
| Dev | http://pgagi-dev-alb-180616274.ap-south-1.elb.amazonaws.com | http://pgagi-dev-alb-180616274.ap-south-1.elb.amazonaws.com/api/health |
| Staging | [staging-alb-url] | [staging-alb-url]/api/health |
| Prod | [prod-alb-url] | [prod-alb-url]/api/health |

### GCP (Cloud Run — asia-south1 Mumbai)

| Environment | Frontend | Backend Health |
|---|---|---|
| Dev | https://pgagi-task-dev-frontend-biwrckq7xa-el.a.run.app | https://pgagi-task-dev-backend-biwrckq7xa-el.a.run.app/api/health |
| Staging | [staging-cloud-run-url] | [staging-cloud-run-url]/api/health |
| Prod | [prod-cloud-run-url] | [prod-cloud-run-url]/api/health |

---

## Architecture Overview

```
AWS                                    GCP
────────────────────────               ──────────────────────────
Internet                               Internet
    ↓                                      ↓
ALB (public, path-based routing)       Cloud Run Frontend (serverless)
    ├── /* → Frontend (ECS Fargate)        ↓ (API calls)
    └── /api/* → Backend (ECS Fargate) Cloud Run Backend (serverless)
                    ↓                          ↓
            Private Subnets            Serverless VPC Connector
                    ↓                          ↓
            NAT Gateway                  Private VPC + Cloud NAT
                    ↓                          ↓
              Amazon ECR               Artifact Registry
```

### Key Architectural Differences

| Dimension | AWS | GCP |
|---|---|---|
| Compute | ECS Fargate (always warm) | Cloud Run (scales to zero) |
| Registry | Amazon ECR | Google Artifact Registry |
| Load Balancer | ALB with path routing | Cloud Run built-in URLs |
| Networking | Private subnets + NAT | VPC Connector + Cloud NAT |
| Auth | OIDC → IAM Role | Workload Identity Federation |

---

## Running Locally

### Prerequisites
- Docker & Docker Compose
- Node.js 20+
- Python 3.11+

### Start the application

```bash
docker compose up --build
```

- Frontend: http://localhost:3000
- Backend: http://localhost:8000
- Health check: http://localhost:8000/api/health

---

## CI/CD Pipeline

```
Push to main
      ↓
Trivy FS Scan (source code)
      ↓
Build Docker Images
  - Backend → ECR + Artifact Registry
  - Frontend (AWS) → ECR (with AWS ALB URL)
  - Frontend (GCP) → Artifact Registry (with Cloud Run URL)
      ↓
Trivy Image Scan
      ↓
Push to Registries
      ↓
Auto-deploy → Dev (AWS + GCP)
      ↓
Manual approval → Staging (AWS + GCP)
      ↓
Manual approval → Prod (AWS + GCP)
```

### Security Scanning

- **Trivy** scans both source code and Docker images for CVEs
- Pipeline fails hard on CRITICAL/HIGH severity vulnerabilities with available fixes
- `.trivyignore` files document acknowledged CVEs with reasoning (base image issues, vendored deps)
- No long-lived credentials anywhere — OIDC on AWS, Workload Identity on GCP

---

## Repository Structure

```
DevOps-Task-PG-AGI/          ← this repo (application code)
├── backend/
│   ├── app/main.py           FastAPI application
│   ├── Dockerfile
│   ├── requirements.txt
│   └── .trivyignore
├── frontend/
│   ├── pages/index.js        Next.js application
│   ├── Dockerfile
│   └── .trivyignore
├── docker-compose.yaml
└── .github/
    └── workflows/
        └── ci.yaml           CI/CD pipeline

PG-AGI-INFRA/                ← separate infra repo
└── infra/
    ├── modules/              Reusable Terraform modules
    ├── aws/                  AWS environments (dev/staging/prod)
    └── gcp/                  GCP environments (dev/staging/prod)
```

---

## Links

- **Infrastructure Repository:** https://github.com/Aayushsoni09/PG-AGI-INFRA
- **Architecture Documentation:** [Google Doc link]
- **Demo Video:** [YouTube/Loom link]

---

## Environment Variables

| Variable | Description | Where Set |
|---|---|---|
| `NEXT_PUBLIC_API_URL` | Backend ALB/Cloud Run URL | GitHub Secret (baked at build time) |
| `AWS_GITHUB_ACTIONS_ROLE_ARN` | IAM role for OIDC | GitHub Secret |
| `GCP_WORKLOAD_IDENTITY_PROVIDER` | GCP Workload Identity | GitHub Secret |
| `GCP_SERVICE_ACCOUNT` | GCP service account email | GitHub Secret |
