# /audit-security

Audit all Terraform files for security vulnerabilities.

## What to do
1. Read all files in modules/security/
2. Read all security_group resources across all modules
3. Read modules/database/main.tf for RDS config
4. Read modules/ec2/main.tf for public IP config
5. Grep for hardcoded credentials: password, secret, key

## Check For (by severity)

### CRITICAL
- [ ] Port 22 open to 0.0.0.0/0 in any security group
- [ ] Port 3306 open to 0.0.0.0/0 in any security group
- [ ] RDS: publicly_accessible = true
- [ ] Hardcoded passwords or secrets in .tf files
- [ ] App tier EC2 with associate_public_ip_address = true

### HIGH
- [ ] RDS: storage_encrypted = false or missing
- [ ] Missing deletion_protection on RDS (in production)
- [ ] IAM roles with * on all resources

### MEDIUM
- [ ] Security groups missing description field
- [ ] Missing tags on resources

### LOW
- [ ] Non-standard ports open without justification comment
- [ ] Missing backup_retention_period on RDS

## Output Format

```
Security Audit Report
=====================

CRITICAL (N findings)
  [1] Description — File: modules/security/main.tf line N
      Fix: ...

HIGH (N findings)
  ...

MEDIUM / LOW
  ...

Verdict: SAFE TO DEPLOY | BLOCKED
Blockers: (list CRITICAL issues if any)
```

## Allowed Tools
- Read (all .tf files)
- Bash(grep *) for pattern matching only

## Never
- Modify any files
- Run any Terraform or AWS commands
