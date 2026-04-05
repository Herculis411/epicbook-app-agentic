# /tf-apply

Apply the Terraform plan to provision real AWS infrastructure.

## Prerequisites (check before running)
- /tf-plan must have been run and returned SAFE TO APPLY
- User must have explicitly confirmed they want to proceed
- terraform.tfvars must have all CHANGE_ME values replaced

## What to do
1. Run: terraform apply tfplan
2. Stream the output — show progress every 60 seconds
3. Note: RDS Multi-AZ takes ~12 minutes — inform the user
4. After apply completes run: terraform output
5. Run health checks:
   - curl -I http://$(terraform output -raw public_alb_dns)
     → expect HTTP 200
   - curl http://$(terraform output -raw public_alb_dns)/api/books
     → expect HTTP 200 with JSON
6. Report results:

```
Deployment Complete
  App URL: http://...elb.amazonaws.com
  Frontend: HTTP 200
  API:      HTTP 200
  Duration: ~N minutes
```

## Expected Duration
- Full stack: 20-25 minutes
- RDS is the bottleneck — do not interrupt

## Allowed Tools
- Bash(terraform apply*)
- Bash(terraform output*)
- Bash(curl *)
- Bash(aws ec2 describe*)
- Bash(aws rds describe*)

## Never
- Skip health checks
- Report success before HTTP 200 confirmed
- Run if user has not confirmed
