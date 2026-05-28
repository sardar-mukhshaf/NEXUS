# =============================================================================
# Conftest Policy: Deny Root Account
# No IAM policy can allow the root account.
# =============================================================================
package terraform.iam

import future.keywords.if
import future.keywords.in

deny contains msg if {
    some resource in input.resource_changes
    resource.type == "aws_iam_policy"
    resource.change.after
    policy := json.unmarshal(resource.change.after.policy)
    some statement in policy.Statement
    statement.Effect == "Allow"
    allows_root(statement)
    msg := sprintf("IAM policy must not allow root account: %s", [resource.address])
}

deny contains msg if {
    some resource in input.resource_changes
    resource.type == "aws_iam_role_policy"
    resource.change.after
    policy := json.unmarshal(resource.change.after.policy)
    some statement in policy.Statement
    statement.Effect == "Allow"
    allows_root(statement)
    msg := sprintf("IAM role policy must not allow root account: %s", [resource.address])
}

allows_root(statement) if {
    statement.Principal.AWS == "arn:aws:iam::*:root"
}

allows_root(statement) if {
    some principal in statement.Principal.AWS
    contains(principal, ":root")
}
