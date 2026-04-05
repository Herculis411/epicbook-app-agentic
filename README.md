<img width="1204" height="2404" alt="image" src="https://github.com/user-attachments/assets/ae981ba3-922a-41bf-9875-1deb24d4d2b3" />



# Book Review App — Infrastructure as Code

Modular Terraform deployment of the Book Review App
(Next.js + Node.js + MySQL) on AWS — three-tier production
architecture with full Claude Code agentic deployment workflow.

---

## Architecture

```
Browser → Public ALB → Web EC2 (Next.js + Nginx)
                              │
                         Nginx /api/* proxy
                              │
                       Internal ALB → App EC2 (Node.js)
                                             │
                                        RDS MySQL
                               (Multi-AZ + Read Replica)
```

---

## What This Deploys

| Component     | Technology           | Details                          |
|---------------|----------------------|----------------------------------|
| Frontend      | Next.js 18 + Nginx   | Web tier, public subnets, 2 AZs  |
| Backend       | Node.js 18 + Express | App tier, private subnets, 2 AZs |
| Database      | RDS MySQL 8.0        | Multi-AZ + read replica          |
| Load Balancers| 2x AWS ALB           | Public + Internal                |
| Networking    | Custom VPC           | 6 subnets across 2 AZs           |

---

## Project Structure (38 files)

```
book-review-app-IaC/
├── .gitignore
├── .mcp.json                       MCP servers (Terraform + AWS)
├── CLAUDE.md                       Claude Code memory + agent rules
├── DEPLOYMENT_GUIDE.md             Step-by-step deployment instructions
├── README.md                       This file
├── main.tf                         Root orchestration module
├── variables.tf                    Root variables
├── outputs.tf                      Root outputs
├── terraform.tfvars                Your values — gitignored
├── terraform.tfvars.example        Safe template to commit
├── .claude/
│   ├── settings.local.json         AWS profile + permissions — gitignored
│   ├── agents/
│   │   ├── infra-engineer.md
│   │   ├── security-auditor.md
│   │   └── debug-agent.md
│   └── skills/
│       ├── tf-plan/SKILL.md
│       ├── tf-apply/SKILL.md
│       ├── tf-destroy/SKILL.md
│       ├── audit-security/SKILL.md
│       └── debug-infra/SKILL.md
├── scripts/
│   ├── deploy-frontend.sh
│   └── deploy-backend.sh
└── modules/
    ├── networking/
    ├── security/
    ├── alb/
    ├── ec2/
    └── database/
```

---

## Quick Start

```bash
# 1. Create AWS key pair
aws ec2 create-key-pair --key-name book-review-key \
  --query 'KeyMaterial' --output text > book-review-key.pem
chmod 400 book-review-key.pem

# 2. Generate JWT secret
openssl rand -base64 48

# 3. Fill in terraform.tfvars
cp terraform.tfvars.example terraform.tfvars
# Edit: key_name, db_password, jwt_secret

# 4. Launch Claude Code
claude

# 5. Deploy
# Prompt: "Use the infra-engineer agent to deploy the book-review-app"
```

Full guide: **DEPLOYMENT_GUIDE.md**

---

## Claude Code Agentic Prompts

```
Audit:   "Run /audit-security before we deploy"
Plan:    "Run /tf-plan and show me what will be created"
Deploy:  "Run /tf-apply to deploy the full stack"
Debug:   "Run /debug-infra to diagnose the failure"
Destroy: "Run /tf-destroy when I am done"
```

---

## Source

Book Review App: https://github.com/pravinmishraaws/book-review-app
