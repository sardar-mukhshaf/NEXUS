#!/usr/bin/env python3
# =============================================================================
# NEXUS PLATFORM — Drift Detector
# Compares Terraform state in S3 to live AWS resources via Boto3.
# Detects: missing resources, tag changes, console modifications.
# =============================================================================
import json
import os
import sys
import boto3
import urllib.request
from datetime import datetime

STATE_BUCKET = os.environ.get("STATE_BUCKET", "nexus-platform-tfstate")
STATE_KEY = os.environ.get("STATE_KEY", "terraform.tfstate")
SNS_TOPIC_ARN = os.environ.get("SNS_TOPIC_ARN", "")
ENVIRONMENT = os.environ.get("ENVIRONMENT", "dev")
AUTO_REMEDIATE = os.environ.get("AUTO_REMEDIATE", "false").lower() == "true"
ATLANTIS_WEBHOOK_URL = os.environ.get("ATLANTIS_WEBHOOK_URL", "")


def get_terraform_state():
    """Download and parse Terraform state from S3."""
    s3 = boto3.client("s3")
    response = s3.get_object(Bucket=STATE_BUCKET, Key=STATE_KEY)
    return json.loads(response["Body"].read())


def get_state_resources(state):
    """Extract resources from Terraform state by type."""
    resources = {}
    for module in state.get("resources", []):
        rtype = module.get("type", "unknown")
        if rtype not in resources:
            resources[rtype] = []
        resources[rtype].extend(module.get("instances", []))
    return resources


def check_ec2_instances(state_resources):
    """Compare EC2 instances in state vs live AWS."""
    ec2 = boto3.client("ec2")
    drifts = []

    state_ids = set()
    for inst in state_resources.get("aws_instance", []):
        attrs = inst.get("attributes", {})
        state_ids.add(attrs.get("id"))

    if not state_ids:
        return drifts

    paginator = ec2.get_paginator("describe_instances")
    live_ids = set()
    for page in paginator.paginate():
        for reservation in page["Reservations"]:
            for instance in reservation["Instances"]:
                live_ids.add(instance["InstanceId"])

    for sid in state_ids:
        if sid and sid not in live_ids:
            drifts.append({
                "resource_type": "aws_instance",
                "resource_id": sid,
                "drift_type": "MISSING_IN_AWS",
                "message": f"EC2 instance {sid} exists in state but not in AWS."
            })

    return drifts


def check_security_groups(state_resources):
    """Compare Security Groups in state vs live AWS."""
    ec2 = boto3.client("ec2")
    drifts = []

    state_sgs = {}
    for sg in state_resources.get("aws_security_group", []):
        attrs = sg.get("attributes", {})
        sg_id = attrs.get("id")
        if sg_id:
            state_sgs[sg_id] = {
                "name": attrs.get("name", ""),
                "description": attrs.get("description", ""),
                "tags": attrs.get("tags", {})
            }

    if not state_sgs:
        return drifts

    try:
        response = ec2.describe_security_groups(GroupIds=list(state_sgs.keys()))
        live_sgs = {g["GroupId"]: g for g in response["SecurityGroups"]}
    except Exception as e:
        drifts.append({
            "resource_type": "aws_security_group",
            "drift_type": "API_ERROR",
            "message": str(e)
        })
        return drifts

    for sg_id, state_sg in state_sgs.items():
        if sg_id not in live_sgs:
            drifts.append({
                "resource_type": "aws_security_group",
                "resource_id": sg_id,
                "drift_type": "MISSING_IN_AWS",
                "message": f"Security Group {sg_id} missing in AWS."
            })
            continue

        live_sg = live_sgs[sg_id]
        live_tags = {t["Key"]: t["Value"] for t in live_sg.get("Tags", [])}
        for k, v in state_sg["tags"].items():
            if live_tags.get(k) != v:
                drifts.append({
                    "resource_type": "aws_security_group",
                    "resource_id": sg_id,
                    "drift_type": "TAG_CHANGED",
                    "message": f"Tag '{k}' changed from '{v}' to '{live_tags.get(k)}'."
                })

    return drifts


def check_iam_policies(state_resources):
    """Compare IAM policies in state vs live AWS."""
    iam = boto3.client("iam")
    drifts = []

    state_arns = set()
    for policy in state_resources.get("aws_iam_policy", []):
        attrs = policy.get("attributes", {})
        state_arns.add(attrs.get("arn"))

    for arn in state_arns:
        if not arn:
            continue
        try:
            iam.get_policy(PolicyArn=arn)
        except iam.exceptions.NoSuchEntityException:
            drifts.append({
                "resource_type": "aws_iam_policy",
                "resource_id": arn,
                "drift_type": "MISSING_IN_AWS",
                "message": f"IAM policy {arn} missing in AWS."
            })

    return drifts


def check_s3_buckets(state_resources):
    """Compare S3 buckets in state vs live AWS."""
    s3 = boto3.client("s3")
    drifts = []

    state_buckets = set()
    for bucket in state_resources.get("aws_s3_bucket", []):
        attrs = bucket.get("attributes", {})
        state_buckets.add(attrs.get("bucket", attrs.get("id", "")))

    try:
        response = s3.list_buckets()
        live_buckets = {b["Name"] for b in response["Buckets"]}
    except Exception as e:
        drifts.append({
            "resource_type": "aws_s3_bucket",
            "drift_type": "API_ERROR",
            "message": str(e)
        })
        return drifts

    for b in state_buckets:
        if b and b not in live_buckets:
            drifts.append({
                "resource_type": "aws_s3_bucket",
                "resource_id": b,
                "drift_type": "MISSING_IN_AWS",
                "message": f"S3 bucket {b} missing in AWS."
            })

    return drifts


def check_route53_records(state_resources):
    """Compare Route53 records in state vs live AWS."""
    route53 = boto3.client("route53")
    drifts = []

    state_records = {}
    for rec in state_resources.get("aws_route53_record", []):
        attrs = rec.get("attributes", {})
        zone_id = attrs.get("zone_id")
        name = attrs.get("name")
        rtype = attrs.get("type")
        key = f"{zone_id}/{name}/{rtype}"
        state_records[key] = attrs

    for key, attrs in state_records.items():
        zone_id = attrs.get("zone_id")
        name = attrs.get("name")
        rtype = attrs.get("type")
        try:
            paginator = route53.get_paginator("list_resource_record_sets")
            found = False
            for page in paginator.paginate(HostedZoneId=zone_id):
                for record in page["ResourceRecordSets"]:
                    if record["Name"] == name and record["Type"] == rtype:
                        found = True
                        break
                if found:
                    break
            if not found:
                drifts.append({
                    "resource_type": "aws_route53_record",
                    "resource_id": key,
                    "drift_type": "MISSING_IN_AWS",
                    "message": f"Route53 record {name} ({rtype}) missing in zone {zone_id}."
                })
        except Exception as e:
            drifts.append({
                "resource_type": "aws_route53_record",
                "drift_type": "API_ERROR",
                "message": str(e)
            })

    return drifts


def check_rds_instances(state_resources):
    """Compare RDS instances in state vs live AWS."""
    rds = boto3.client("rds")
    drifts = []

    state_ids = set()
    for db in state_resources.get("aws_db_instance", []):
        attrs = db.get("attributes", {})
        state_ids.add(attrs.get("id"))
    for db in state_resources.get("aws_rds_cluster", []):
        attrs = db.get("attributes", {})
        state_ids.add(attrs.get("id"))

    if not state_ids:
        return drifts

    try:
        response = rds.describe_db_instances()
        live_ids = {d["DBInstanceIdentifier"] for d in response["DBInstances"]}
    except Exception as e:
        drifts.append({
            "resource_type": "aws_db_instance",
            "drift_type": "API_ERROR",
            "message": str(e)
        })
        return drifts

    for sid in state_ids:
        if sid and sid not in live_ids:
            drifts.append({
                "resource_type": "aws_db_instance",
                "resource_id": sid,
                "drift_type": "MISSING_IN_AWS",
                "message": f"RDS instance {sid} missing in AWS."
            })

    return drifts


def publish_alert(drifts):
    """Publish drift findings to SNS."""
    if not SNS_TOPIC_ARN or not drifts:
        return

    sns = boto3.client("sns")
    message = {
        "default": json.dumps({
            "environment": ENVIRONMENT,
            "timestamp": datetime.utcnow().isoformat(),
            "drift_count": len(drifts),
            "findings": drifts
        }, indent=2)
    }

    sns.publish(
        TopicArn=SNS_TOPIC_ARN,
        Message=json.dumps(message),
        MessageStructure="json",
        Subject=f"[DRIFT] {len(drifts)} drift(s) detected in {ENVIRONMENT}"
    )


def trigger_atlantis_plan():
    """Optionally trigger Atlantis plan for auto-remediation."""
    if not AUTO_REMEDIATE or not ATLANTIS_WEBHOOK_URL:
        return

    try:
        req = urllib.request.Request(
            ATLANTIS_WEBHOOK_URL,
            data=b'{}',
            headers={"Content-Type": "application/json"},
            method="POST"
        )
        with urllib.request.urlopen(req, timeout=10) as resp:
            print(f"Atlantis webhook response: {resp.status}")
    except Exception as e:
        print(f"Failed to trigger Atlantis: {e}")


def handler(event, context):
    """Lambda handler entry point."""
    print(f"[DRIFT] Starting drift detection for environment: {ENVIRONMENT}")

    try:
        state = get_terraform_state()
        state_resources = get_state_resources(state)
    except Exception as e:
        print(f"[ERROR] Failed to load Terraform state: {e}")
        return {"statusCode": 500, "body": str(e)}

    all_drifts = []
    all_drifts.extend(check_ec2_instances(state_resources))
    all_drifts.extend(check_security_groups(state_resources))
    all_drifts.extend(check_iam_policies(state_resources))
    all_drifts.extend(check_s3_buckets(state_resources))
    all_drifts.extend(check_route53_records(state_resources))
    all_drifts.extend(check_rds_instances(state_resources))

    print(f"[DRIFT] Found {len(all_drifts)} drift(s)")
    for d in all_drifts:
        print(f"  - {d['drift_type']}: {d.get('resource_id', 'N/A')} | {d['message']}")

    if all_drifts:
        publish_alert(all_drifts)
        if AUTO_REMEDIATE:
            trigger_atlantis_plan()

    return {
        "statusCode": 200,
        "body": json.dumps({
            "drift_count": len(all_drifts),
            "findings": all_drifts
        })
    }


if __name__ == "__main__":
    # Local execution support
    handler({}, {})
