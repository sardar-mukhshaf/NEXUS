# =============================================================================
# Conftest Policy: Mandatory Annotations
# Every resource must have description and managed-by annotations.
# =============================================================================
package terraform.annotations

import future.keywords.if
import future.keywords.in

required_annotations := {"description", "managed-by"}

deny contains msg if {
    some resource in input.resource_changes
    resource.change.after
    resource.change.after.annotations
    missing := required_annotations - object.keys(resource.change.after.annotations)
    count(missing) > 0
    msg := sprintf("Resource %s is missing required annotations: %v", [resource.address, missing])
}

deny contains msg if {
    some resource in input.resource_changes
    resource.change.after
    resource.change.after.annotations
    some ann in required_annotations
    not resource.change.after.annotations[ann]
    msg := sprintf("Resource %s has empty required annotation: %s", [resource.address, ann])
}
