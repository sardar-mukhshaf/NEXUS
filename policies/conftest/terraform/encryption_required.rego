# =============================================================================
# Conftest Policy: Encryption Required
# EBS, RDS, and S3 must have encryption enabled.
# =============================================================================
package terraform.encryption

import future.keywords.if
import future.keywords.in

deny contains msg if {
    some resource in input.resource_changes
    resource.type == "aws_ebs_volume"
    resource.change.after
    not resource.change.after.encrypted
    msg := sprintf("EBS volume must be encrypted: %s", [resource.address])
}

deny contains msg if {
    some resource in input.resource_changes
    resource.type == "aws_db_instance"
    resource.change.after
    not resource.change.after.storage_encrypted
    msg := sprintf("RDS instance must have storage encryption: %s", [resource.address])
}

deny contains msg if {
    some resource in input.resource_changes
    resource.type == "aws_s3_bucket_server_side_encryption_configuration"
    resource.change.after
    not has_valid_encryption(resource.change.after.rule)
    msg := sprintf("S3 bucket must have valid server-side encryption: %s", [resource.address])
}

deny contains msg if {
    some resource in input.resource_changes
    resource.type == "aws_s3_bucket"
    resource.change.after
    not has_encryption_resource(resource.address)
    msg := sprintf("S3 bucket must have encryption configuration: %s", [resource.address])
}

has_valid_encryption(rule) if {
    rule.apply_server_side_encryption_by_default.sse_algorithm == "aws:kms"
}

has_valid_encryption(rule) if {
    rule.apply_server_side_encryption_by_default.sse_algorithm == "AES256"
}

has_encryption_resource(bucket_address) if {
    some resource in input.resource_changes
    resource.type == "aws_s3_bucket_server_side_encryption_configuration"
    contains(resource.address, bucket_address)
}
