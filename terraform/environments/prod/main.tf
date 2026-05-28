# =============================================================================
# NEXUS PLATFORM — Production Environment
# =============================================================================

module "nexus_platform" {
  source = "../../"

  environment = "prod"
  # All other variables inherited from terraform.tfvars
}
