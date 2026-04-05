# CLAUDE.md — Book Review App IaC

## Agent Instructions

You are an AI DevOps engineer responsible for deploying and
maintaining the Book Review App infrastructure on AWS using Terraform.

### Your Capabilities
- Run Terraform commands autonomously
- Read and modify .tf files
- Execute AWS CLI commands to verify deployments
- Debug infrastructure errors and fix them without being asked

### Your Workflow
1. Always run terraform plan before apply
2. Always confirm with the user before terraform apply
3. Fix Terraform errors autonomously — do not ask unless genuinely stuck
4. After apply, run health checks before reporting success
5. Never report success until HTTP 200 is confirmed on the ALB

### Hard Rules — Never Break These
- Never commit terraform.tfvars to git
- Never assign public IPs to app or db tier instances
- Never hardcode credentials in any .tf file
- Never run terraform destroy without explicit user confirmation
- Never open port 3306 to 0.0.0.0/0
- Never set RDS publicly_accessible = true

---

## Project Overview

Deploys the **Book Review App** (Next.js + Node.js + MySQL)
on **AWS** using a fully modular Terraform architecture.

---

## Architecture

```
Internet
   │
   ▼
[Public ALB]            port 80 — internet-facing
   │
   ▼
[Web EC2 x2]            Next.js via Nginx, public subnets, 2 AZs
   │  Nginx /api/*
   ▼
[Internal ALB]          port 3001 — internal only
   │
   ▼
[App EC2 x2]            Node.js API, private subnets, 2 AZs
   │
   ▼ port 3306
[RDS MySQL]             primary + read replica, private subnets
```

### How the Frontend API Proxy Works

```
Browser calls: http://PUBLIC_ALB_DNS/api/books
                       ↓
          Nginx on Web EC2 catches /api/*
                       ↓
          Proxies to: http://INTERNAL_ALB_DNS:3001/api/books
                       ↓
          Internal ALB routes to App EC2 (Node.js)
                       ↓
          Node.js queries RDS MySQL
```

The browser never directly contacts the Internal ALB.
`NEXT_PUBLIC_API_URL` is set to the Public ALB DNS.
Nginx acts as the API gateway.

---

## Subnet Layout (VPC: 10.0.0.0/16)

| Tier | Subnet        | AZ          | Type    |
|------|---------------|-------------|---------|
| Web  | 10.0.1.0/24   | us-east-1a  | Public  |
| Web  | 10.0.2.0/24   | us-east-1b  | Public  |
| App  | 10.0.3.0/24   | us-east-1a  | Private |
| App  | 10.0.4.0/24   | us-east-1b  | Private |
| DB   | 10.0.5.0/24   | us-east-1a  | Private |
| DB   | 10.0.6.0/24   | us-east-1b  | Private |

---

## Module Structure

```
modules/
├── networking/   VPC, 6 subnets, IGW, 2x NAT Gateway, route tables
├── security/     5 security groups (public-alb, web, internal-alb, app, db)
├── alb/          Public ALB (port 80) + Internal ALB (port 3001)
├── ec2/          2x web EC2 + 2x app EC2 + SSM IAM role
└── database/     RDS MySQL 8.0 Multi-AZ primary + read replica

scripts/
├── deploy-frontend.sh   Next.js bootstrap — injected by templatefile()
└── deploy-backend.sh    Node.js bootstrap — injected by templatefile()
```

---

## Security Group Rules

| From         | To           | Port | Rule             |
|--------------|--------------|------|------------------|
| Internet     | Public ALB   | 80   | Open             |
| Public ALB   | Web EC2      | 80   | ALB SG only      |
| Web EC2      | Internal ALB | 3001 | Web SG only      |
| Internal ALB | App EC2      | 3001 | Internal ALB SG  |
| App EC2      | RDS MySQL    | 3306 | App SG only      |

---

## Available Skills

| Skill            | Purpose                               |
|------------------|---------------------------------------|
| /tf-plan         | Preview changes with risk assessment  |
| /tf-apply        | Deploy infrastructure to AWS          |
| /tf-destroy      | Tear down all resources safely        |
| /audit-security  | Review security rules for compliance  |
| /debug-infra     | Diagnose and fix deployment failures  |

---

## Available Subagents

| Agent             | Role                                  |
|-------------------|---------------------------------------|
| infra-engineer    | Terraform provisioning and management |
| security-auditor  | Pre-deploy security review            |
| debug-agent       | Diagnose and fix runtime failures     |

---

## Prerequisites

```bash
# AWS CLI configured
aws configure
aws sts get-caller-identity

# Terraform installed
terraform --version   # must be >= 1.5.0

# Key pair exists in AWS
aws ec2 describe-key-pairs --key-names book-review-key

# terraform.tfvars filled in
cat terraform.tfvars
```

---

## Deployment Commands

```bash
terraform init
terraform plan
terraform apply       # 20-25 min total — RDS Multi-AZ is slowest
terraform output app_url
terraform destroy     # only when completely done
```

---

## Deployment Timeline

| Stage                        | Time      |
|------------------------------|-----------|
| Networking (VPC, NAT, routes)| ~3 min    |
| Security groups              | ~1 min    |
| ALBs                         | ~3 min    |
| RDS Multi-AZ primary         | ~12 min   |
| RDS read replica             | ~8 min    |
| EC2 bootstrap (both tiers)   | ~5 min    |
| **Total**                    | ~20-25 min|

---

## Health Check Commands

```bash
# App is live
curl -I http://$(terraform output -raw public_alb_dns)

# API is working
curl http://$(terraform output -raw public_alb_dns)/api/books

# EC2 instances
aws ec2 describe-instances \
  --filters "Name=tag:Project,Values=book-review" \
  --query "Reservations[].Instances[].{Name:Tags[?Key=='Name']|[0].Value,State:State.Name}" \
  --output table

# RDS status
aws rds describe-db-instances \
  --query "DBInstances[].{ID:DBInstanceIdentifier,Status:DBInstanceStatus}" \
  --output table
```

---

## Troubleshooting

### 502 Bad Gateway on frontend
Next.js on port 3000 not ready. Check:
```bash
# Via SSM on web instance
pm2 status
pm2 logs book-review-frontend
```

### API calls failing
Backend not running or DB connection failed. Check:
```bash
# Via SSM on app instance
pm2 status
pm2 logs book-review-backend
tail -f /var/log/book-review-setup.log
```

### RDS connection refused
RDS still initialising — bootstrap retries every 15s for up to 10 min.
```bash
aws rds describe-db-instances \
  --db-instance-identifier book-review-production-mysql-primary \
  --query "DBInstances[0].DBInstanceStatus"
```

### terraform apply fails on RDS replica
Run `terraform apply` again — eventual consistency issue with Multi-AZ.

---

## Cost Estimate (us-east-1, approximate)

| Resource              | Cost/month |
|-----------------------|------------|
| 4x EC2 t3.small       | ~$30       |
| RDS db.t3.micro Multi-AZ | ~$30    |
| RDS read replica      | ~$15       |
| 2x NAT Gateway        | ~$65       |
| 2x ALB                | ~$35       |
| **Total**             | **~$175**  |

Run `terraform destroy` immediately after the assignment to stop billing.
