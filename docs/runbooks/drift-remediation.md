# Drift Remediation Runbook

## What Is Drift?

Drift occurs when live AWS resources differ from the Terraform state. This usually happens due to manual console changes.

## Detection

The drift detection Lambda runs every 15 minutes and compares:
- EC2 instances
- Security Groups
- IAM policies
- S3 buckets
- Route53 records
- RDS instances

## Alert Channels

- SNS → Email
- Slack (#platform-alerts)
- PagerDuty (for production drift)

## Remediation Steps

### Option 1: Automated Remediation (if enabled)

If `drift_auto_remediate = true`, Atlantis will automatically trigger a plan/apply.

### Option 2: Manual Remediation

1. Identify the drifted resource from the alert
2. Decide: **Import** the change or **Revert** it
3. If importing:
   ```bash
   terraform import aws_instance.example i-1234567890abcdef0
   ```
4. If reverting:
   ```bash
   terraform plan
   terraform apply
   ```

## False Positives

Some changes are expected and not true drift:
- AWS-managed tags added by services
- Auto-scaling events
- Backup snapshots

Add exclusions to `scripts/drift-detector.py` if needed.
