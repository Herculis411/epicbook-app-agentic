# /tf-destroy

Safely destroy all infrastructure and confirm complete removal.

## CRITICAL — Always Confirm First

Before running anything, say to the user:

"WARNING: This will permanently destroy ALL infrastructure including:
  - 4 EC2 instances (web and app tiers)
  - RDS MySQL primary + read replica
  - All networking (VPC, subnets, NAT gateways, ALBs)
  - All data in the database

This cannot be undone. Type YES to confirm."

Only proceed if the user types YES.

## What to do
1. Get explicit YES confirmation from the user
2. Run: terraform destroy -auto-approve
3. After destroy completes verify:
   - aws ec2 describe-instances --filters Name=tag:Project,Values=book-review
     → should return empty or terminated
   - aws rds describe-db-instances
     → book-review instances should not exist
4. Confirm to the user: "All resources destroyed. Billing stopped."

## Allowed Tools
- Bash(terraform destroy*)
- Bash(aws ec2 describe*)
- Bash(aws rds describe*)

## Never
- Run without the user typing YES
- Use -auto-approve without asking first
