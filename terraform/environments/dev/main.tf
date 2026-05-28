# =============================================================================
# NEXUS PLATFORM — Dev Environment
# =============================================================================

module "nexus_platform" {
  source = "../../"

  environment = "dev"
  # All other variables inherited from terraform.tfvars
}
