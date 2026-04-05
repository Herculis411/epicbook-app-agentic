# /tf-plan

Run terraform plan and produce a risk-assessed report.

## What to do
1. Run: terraform init -upgrade (ensures providers are current)
2. Run: terraform plan -out=tfplan
3. Analyse the plan output for:
   - Resources being DESTROYED (HIGH RISK — flag immediately)
   - Security groups opening 0.0.0.0/0 on port 22 or 3306
   - RDS instances with publicly_accessible = true
   - Any unexpected resource count changes
4. Produce a clean report:

```
Plan Summary
  + N to add
  ~ N to change
  - N to destroy

Risk Assessment: SAFE TO APPLY | DO NOT APPLY

Key resources:
  + (list main resources being created)

Warnings:
  (list anything the user should review)
```

## Allowed Tools
- Bash(terraform init*)
- Bash(terraform plan*)
- Read (all .tf files)

## Never
- Run terraform apply
- Modify any .tf files
- Delete any files
