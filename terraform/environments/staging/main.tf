# =============================================================================
# NEXUS PLATFORM — Staging Environment
# =============================================================================

module "nexus_platform" {
  source = "../../"

  environment = "staging"
  # All other variables inherited from terraform.tfvars
}
