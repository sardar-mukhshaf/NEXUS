# =============================================================================
# Conftest Policy: No Public S3 Buckets
# Prevents S3 buckets from having public ACLs or public policies.
# =============================================================================
package terraform.s3

import future.keywords.if
import future.keywords.in

deny contains msg if {
    some resource in input.resource_changes
    resource.type == "aws_s3_bucket_public_access_block"
    resource.change.after
    not all_blocked(resource.change.after)
    msg := sprintf("S3 public access block must block all public access: %s", [resource.address])
}

deny contains msg if {
    some resource in input.resource_changes
    resource.type == "aws_s3_bucket_policy"
    resource.change.after
    contains_public_principal(resource.change.after.policy)
    msg := sprintf("S3 bucket policy cannot contain public principal: %s", [resource.address])
}

all_blocked(block) if {
    block.block_public_acls == true
    block.ignore_public_acls == true
    block.block_public_policy == true
    block.restrict_public_buckets == true
}

contains_public_principal(policy_json) if {
    policy := json.unmarshal(policy_json)
    some statement in policy.Statement
    statement.Principal == "*"
}

contains_public_principal(policy_json) if {
    policy := json.unmarshal(policy_json)
    some statement in policy.Statement
    statement.Principal.AWS == "*"
}
