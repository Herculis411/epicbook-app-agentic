# Deployment Guide — Book Review App IaC

Step-by-step guide to deploy using Claude Code with full agentic workflow.

---

## Prerequisites Checklist

Before starting confirm all four are ready:

```bash
# 1. AWS CLI installed and authenticated
aws sts get-caller-identity
# Expected: your account ID and IAM user ARN

# 2. Terraform installed
terraform --version
# Expected: Terraform v1.5.0 or higher

# 3. Claude Code installed
claude --version

# 4. Python uvx available (for MCP servers)
uvx --version
# If missing: pip install uv
```

---

## Step 1 — Create AWS Key Pair

Run from inside the project directory:

```bash
cd ~/projects/book-review-app-IaC

aws ec2 create-key-pair \
  --key-name book-review-key \
  --query 'KeyMaterial' \
  --output text > book-review-key.pem

chmod 400 book-review-key.pem

# Verify key exists in AWS
aws ec2 describe-key-pairs --key-names book-review-key
```

---

## Step 2 — Generate JWT Secret

```bash
openssl rand -base64 48
# Copy the output — paste into terraform.tfvars below
```

---

## Step 3 — Fill in terraform.tfvars

```bash
cp terraform.tfvars.example terraform.tfvars
code terraform.tfvars
```

Replace the three CHANGE_ME values:

```hcl
key_name    = "book-review-key"
db_password = "YourStrong@Pass2026!"
jwt_secret  = "paste-your-openssl-output-here"
```

Save the file. Confirm it is gitignored:

```bash
git check-ignore -v terraform.tfvars
# Expected: .gitignore:1:terraform.tfvars  terraform.tfvars
```

---

## Step 4 — Launch Claude Code

```bash
claude
```

Claude Code reads `CLAUDE.md` automatically and knows the full
architecture, module structure, and deployment rules.

---

## Step 5 — Security Audit (Pre-Deploy)

Type this prompt in Claude Code:

```
Use the security-auditor agent to run /audit-security and
confirm the infrastructure is safe to deploy.
```

Expected output:

```
Security Audit Report
  CRITICAL: 0 findings
  HIGH:     0 findings
  MEDIUM:   0 findings

Verdict: SAFE TO DEPLOY
```

---

## Step 6 — Plan the Infrastructure

```
Use the infra-engineer agent to run /tf-plan and show
me a summary of what will be created.
```

Expected plan summary:

```
Plan Summary
  + 12 resources to add
  ~ 0 to change
  - 0 to destroy

Risk Assessment: SAFE TO APPLY

Key resources:
  + aws_vpc.main
  + 6x aws_subnet (web x2, app x2, db x2)
  + aws_internet_gateway + 2x aws_nat_gateway
  + aws_security_group x5
  + aws_lb x2 (public + internal)
  + aws_instance x4 (web x2, app x2)
  + aws_db_instance x2 (primary + replica)
```

---

## Step 7 — Deploy

```
The plan looks good. Use the infra-engineer agent to
run /tf-apply and deploy the full stack.
```

Claude Code will:
1. Run `terraform apply`
2. Stream progress output
3. Wait for RDS (~12 min) — inform you of progress
4. Run health checks automatically
5. Report the app URL

**Total time: 20-25 minutes**

Expected completion output:

```
Deployment Complete
  App URL:   http://book-review-production-pub-alb-xxxx.us-east-1.elb.amazonaws.com
  Frontend:  HTTP 200
  API:       HTTP 200
  Duration:  ~22 minutes
```

---

## Step 8 — Open the App

Open the URL from Step 7 in your browser.

Test the full flow:
1. Homepage loads with book listings
2. Register a new account
3. Log in with your credentials
4. Browse to a book detail page
5. Submit a review
6. Confirm the review appears immediately

---

## Step 9 — Capture Screenshots for Submission

```bash
# EC2 instances
aws ec2 describe-instances \
  --filters "Name=tag:Project,Values=book-review" \
  --query "Reservations[].Instances[].{Name:Tags[?Key=='Name']|[0].Value,State:State.Name,Type:InstanceType}" \
  --output table

# RDS instances
aws rds describe-db-instances \
  --query "DBInstances[].{ID:DBInstanceIdentifier,Status:DBInstanceStatus,MultiAZ:MultiAZ}" \
  --output table

# ALB DNS
terraform output public_alb_dns
terraform output internal_alb_dns
```

Screenshots needed:
- [ ] terraform apply output
- [ ] EC2 dashboard (4 instances running)
- [ ] RDS dashboard (primary + read replica)
- [ ] Book Review App in browser (homepage)
- [ ] Registration flow working
- [ ] Review submission working

---

## Step 10 — Debug If Needed

If the app is not responding:

```
Use the debug-agent to run /debug-infra and diagnose
why the app is not responding.
```

Claude Code will check each layer and identify the root cause.

---

## Step 11 — Destroy When Done

```
I have finished the assignment. Use /tf-destroy to
destroy all infrastructure.
```

Claude Code will ask for explicit confirmation before destroying anything.

Confirm by typing **YES** when prompted.

Verify destruction:

```bash
aws ec2 describe-instances \
  --filters "Name=tag:Project,Values=book-review" \
  --query "Reservations[].Instances[].State.Name" \
  --output text
# Expected: terminated (or empty)
```

---

## Troubleshooting Quick Reference

| Symptom | Likely Cause | Fix |
|---|---|---|
| 502 Bad Gateway | Next.js not started yet | Wait 5 min, check pm2 status |
| API calls fail | Backend not running | Check pm2 on app EC2 via SSM |
| DB connection refused | RDS still starting | Wait, bootstrap retries auto |
| terraform apply error on replica | RDS eventual consistency | Re-run terraform apply |
| HCL syntax error | Semicolons in variables.tf | Use newlines not semicolons |
| SG description error | Non-ASCII chars (em dashes) | Use hyphens only |

---

## MCP Servers

This project uses two MCP servers for Claude Code:

| Server | Purpose |
|---|---|
| terraform MCP | Live Terraform AWS provider docs — correct resource syntax |
| aws MCP | Live AWS service docs — current instance types, AMI IDs |

Start MCP in Claude Code:

```
/mcp
```

Both servers should show as connected before deploying.

---

## Cost Reminder

| Resource | Cost/month |
|---|---|
| 4x EC2 t3.small | ~$30 |
| RDS db.t3.micro Multi-AZ | ~$30 |
| RDS read replica | ~$15 |
| 2x NAT Gateway | ~$65 |
| 2x ALB | ~$35 |
| **Total** | **~$175** |

Always run `terraform destroy` after completing the assignment.
