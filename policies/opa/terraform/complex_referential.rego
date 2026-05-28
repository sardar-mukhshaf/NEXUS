# =============================================================================
# OPA Policy: Complex Referential Policies for Terraform Plans
# Validates cross-resource relationships that Conftest cannot easily check.
# =============================================================================
package terraform

import future.keywords.if
import future.keywords.in

# Deny if a security group allows ingress from 0.0.0.0/0 on port 22
deny contains msg if {
    some sg in input.resource_changes
    sg.type == "aws_security_group_rule"
    sg.change.after
    sg.change.after.type == "ingress"
    sg.change_after.cidr_blocks[_] == "0.0.0.0/0"
    sg.change.after.from_port <= 22
    sg.change.after.to_port >= 22
    msg := sprintf("Security group rule must not allow SSH from 0.0.0.0/0: %s", [sg.address])
}

# Deny if an RDS instance is publicly accessible
deny contains msg if {
    some db in input.resource_changes
    db.type == "aws_db_instance"
    db.change.after
    db.change.after.publicly_accessible == true
    msg := sprintf("RDS instance must not be publicly accessible: %s", [db.address])
}

# Deny if an EKS cluster has public endpoint without restricted CIDRs
deny contains msg if {
    some cluster in input.resource_changes
    cluster.type == "aws_eks_cluster"
    cluster.change.after
    cluster.change.after.vpc_config.endpoint_public_access == true
    not has_public_access_cidrs(cluster.change.after.vpc_config)
    msg := sprintf("EKS cluster with public endpoint must restrict public access CIDRs: %s", [cluster.address])
}

has_public_access_cidrs(vpc_config) if {
    count(vpc_config.public_access_cidrs) > 0
    vpc_config.public_access_cidrs[_] != "0.0.0.0/0"
}
