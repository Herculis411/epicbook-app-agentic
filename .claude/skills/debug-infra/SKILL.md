# /debug-infra

Diagnose a failing Book Review App deployment.

## What to do

### Step 1 — Collect Instance IDs
```bash
terraform output web_instance_ids
terraform output app_instance_ids
terraform output public_alb_dns
terraform output internal_alb_dns
terraform output db_hostname
```

### Step 2 — Check EC2 States
```bash
aws ec2 describe-instances \
  --filters "Name=tag:Project,Values=book-review" \
  --query "Reservations[].Instances[].{Name:Tags[?Key=='Name']|[0].Value,State:State.Name,ID:InstanceId}" \
  --output table
```

### Step 3 — Test Each Layer
```bash
# Layer 1: Public ALB reachable?
curl -I http://PUBLIC_ALB_DNS

# Layer 2: API reachable via Nginx proxy?
curl http://PUBLIC_ALB_DNS/api/books

# Layer 3: RDS reachable? (check via SSM on app EC2)
aws ssm start-session --target APP_INSTANCE_ID \
  --document-name AWS-StartInteractiveCommand \
  --parameters command='mysql -h DB_HOST -u admin -p -e "SELECT 1;"'
```

### Step 4 — Check Bootstrap Logs via SSM
```bash
# Web EC2 bootstrap log
aws ssm start-session --target WEB_INSTANCE_ID \
  --document-name AWS-StartInteractiveCommand \
  --parameters command='tail -100 /var/log/book-review-setup.log'

# App EC2 bootstrap log
aws ssm start-session --target APP_INSTANCE_ID \
  --document-name AWS-StartInteractiveCommand \
  --parameters command='tail -100 /var/log/book-review-setup.log'
```

### Step 5 — Check PM2 Status
```bash
# Web EC2
aws ssm start-session --target WEB_INSTANCE_ID \
  --document-name AWS-StartInteractiveCommand \
  --parameters command='sudo -u ubuntu pm2 status && sudo -u ubuntu pm2 logs book-review-frontend --lines 30'

# App EC2
aws ssm start-session --target APP_INSTANCE_ID \
  --document-name AWS-StartInteractiveCommand \
  --parameters command='sudo -u ubuntu pm2 status && sudo -u ubuntu pm2 logs book-review-backend --lines 30'
```

## Output Format

```
Diagnostic Report
=================
Public ALB:      HTTP N
API /api/books:  HTTP N
Web EC2 state:   running/stopped
App EC2 state:   running/stopped
RDS status:      available/creating

Root Cause: ...
Fix Applied: ...
Health Check After Fix: HTTP N
```

## Allowed Tools
- Bash(terraform output*)
- Bash(aws ec2 describe*)
- Bash(aws rds describe*)
- Bash(aws ssm start-session*)
- Bash(curl *)
- Read (scripts/*.sh for reference)
