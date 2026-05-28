# Break-Glass Runbook

## When to Use

Emergency situations where automated remediation is insufficient:
- Critical production incident requiring immediate manual intervention
- Terraform state corruption
- Complete platform outage

## Approval Workflow

1. **Request**: Engineer runs `make break-glass REASON="..." APPROVER="..."`
2. **4-Eyes Approval**: Senior engineer or on-call must approve via Slack
3. **Logging**: All access is logged to CloudTrail, Slack, and PagerDuty
4. **Timebox**: Access expires after 1 hour
5. **Post-Incident**: All manual changes must be imported back into Terraform

## Commands

```bash
# Request break-glass access
make break-glass

# Or directly
./scripts/break-glass.sh "Incident description" "approver@example.com"
```

## Post-Incident Cleanup

```bash
# Import manual changes
terraform import aws_instance.example i-1234567890abcdef0

# Validate state
terraform plan

# Revoke break-glass access
aws iam detach-role-policy --role-name break-glass --policy-arn ...
```
