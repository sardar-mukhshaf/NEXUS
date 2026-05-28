# =============================================================================
# Conftest Policy: Required Tags
# Every resource must have Environment, Team, CostCenter, and Description tags.
# =============================================================================
package terraform.tags

import future.keywords.if
import future.keywords.in

required_tags := {"Environment", "Team", "CostCenter", "Description", "ManagedBy"}

deny contains msg if {
    some resource in input.resource_changes
    resource.change.after
    resource.change.after.tags
    missing := required_tags - object.keys(resource.change.after.tags)
    count(missing) > 0
    msg := sprintf("Resource %s is missing required tags: %v", [resource.address, missing])
}

deny contains msg if {
    some resource in input.resource_changes
    resource.change.after
    resource.change.after.tags
    some tag in required_tags
    not resource.change.after.tags[tag]
    msg := sprintf("Resource %s has empty required tag: %s", [resource.address, tag])
}
