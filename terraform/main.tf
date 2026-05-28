locals {
  naming_prefix = "${var.project_name}-${var.environment}"
  computed_tags = merge(var.common_tags, {
    Environment = var.environment
    GitCommit   = var.git_commit_sha
    Description = var.resource_description
  })
}

# =============================================================================
# Module 1: Networking
# =============================================================================
module "networking" {
  source = "./modules/networking"

  project_name              = var.project_name
  environment               = var.environment
  naming_prefix             = local.naming_prefix
  vpc_cidr                  = var.vpc_cidr
  availability_zones        = var.availability_zones
  public_subnet_cidrs       = var.public_subnet_cidrs
  private_subnet_cidrs      = var.private_subnet_cidrs
  database_subnet_cidrs     = var.database_subnet_cidrs
  enable_nat_gateway        = var.enable_nat_gateway
  single_nat_gateway        = var.single_nat_gateway
  enable_vpn_gateway        = var.enable_vpn_gateway
  enable_flow_logs          = var.enable_flow_logs
  flow_logs_retention_days  = var.flow_logs_retention_days
  enable_vpc_endpoints      = var.enable_vpc_endpoints
  common_tags               = local.computed_tags
  git_commit_sha            = var.git_commit_sha
  resource_description      = var.resource_description
}

# =============================================================================
# Module 2: EKS Platform
# =============================================================================
module "eks_platform" {
  source = "./modules/eks_platform"

  project_name                    = var.project_name
  environment                     = var.environment
  naming_prefix                   = local.naming_prefix
  cluster_name                    = var.cluster_name
  cluster_version                 = var.cluster_version
  cluster_endpoint_public_access  = var.cluster_endpoint_public_access
  cluster_endpoint_private_access = var.cluster_endpoint_private_access
  node_groups                     = var.node_groups
  fargate_profiles                = var.fargate_profiles
  cluster_pod_security_standard   = var.cluster_pod_security_standard
  enable_guardduty                = var.enable_guardduty
  enable_security_hub             = var.enable_security_hub
  vpc_id                          = module.networking.vpc_id
  private_subnet_ids              = module.networking.private_subnet_ids
  common_tags                     = local.computed_tags
  git_commit_sha                  = var.git_commit_sha
  resource_description            = var.resource_description
}

# =============================================================================
# Module 3: ArgoCD Self-Managed
# =============================================================================
module "argocd_self_managed" {
  source = "./modules/argocd_self_managed"

  project_name         = var.project_name
  environment          = var.environment
  naming_prefix        = local.naming_prefix
  argocd_enabled       = var.argocd_enabled
  argocd_version       = var.argocd_version
  argocd_domain        = var.argocd_domain
  argocd_admin_enabled = var.argocd_admin_enabled
  argocd_sso_enabled   = var.argocd_sso_enabled
  argocd_self_heal     = var.argocd_self_heal
  argocd_prune         = var.argocd_prune
  cluster_name         = module.eks_platform.cluster_name
  cluster_endpoint     = module.eks_platform.cluster_endpoint
  cluster_ca_certificate = module.eks_platform.cluster_ca_certificate
  oidc_provider_arn    = module.eks_platform.oidc_provider_arn
  oidc_provider_url    = module.eks_platform.oidc_provider_url
  common_tags          = local.computed_tags
  git_commit_sha       = var.git_commit_sha
  resource_description = var.resource_description
}

# =============================================================================
# Module 4: Secrets (SOPS)
# =============================================================================
module "secrets_sops" {
  source = "./modules/secrets_sops"

  project_name         = var.project_name
  environment          = var.environment
  naming_prefix        = local.naming_prefix
  sops_enabled         = var.sops_enabled
  sops_kms_key_arn_dev = var.sops_kms_key_arn_dev
  sops_kms_key_arn_prod = var.sops_kms_key_arn_prod
  common_tags          = local.computed_tags
  git_commit_sha       = var.git_commit_sha
  resource_description = var.resource_description
}

# =============================================================================
# Module 5: External Secrets
# =============================================================================
module "external_secrets" {
  source = "./modules/external_secrets"

  project_name             = var.project_name
  environment              = var.environment
  naming_prefix            = local.naming_prefix
  external_secrets_enabled = var.external_secrets_enabled
  external_secrets_version = var.external_secrets_version
  cluster_name             = module.eks_platform.cluster_name
  oidc_provider_arn        = module.eks_platform.oidc_provider_arn
  common_tags              = local.computed_tags
  git_commit_sha           = var.git_commit_sha
  resource_description     = var.resource_description
}

# =============================================================================
# Module 6: Kyverno Policies
# =============================================================================
module "kyverno_policies" {
  source = "./modules/kyverno_policies"

  project_name             = var.project_name
  environment              = var.environment
  naming_prefix            = local.naming_prefix
  kyverno_enabled          = var.kyverno_enabled
  kyverno_version          = var.kyverno_version
  kyverno_policies_enforce = var.kyverno_policies_enforce
  cluster_name             = module.eks_platform.cluster_name
  oidc_provider_arn        = module.eks_platform.oidc_provider_arn
  ecr_registry_url         = module.devsecops_pipeline.ecr_registry_url
  cosign_kms_key_arn       = module.signing_infrastructure.cosign_kms_key_arn
  common_tags              = local.computed_tags
  git_commit_sha           = var.git_commit_sha
  resource_description     = var.resource_description
}

# =============================================================================
# Module 7: Signing Infrastructure
# =============================================================================
module "signing_infrastructure" {
  source = "./modules/signing_infrastructure"

  project_name           = var.project_name
  environment            = var.environment
  naming_prefix          = local.naming_prefix
  enable_cosign_kms      = var.enable_cosign_kms
  cosign_kms_key_alias   = var.cosign_kms_key_alias
  enable_keyless_signing = var.enable_keyless_signing
  github_oidc_provider_arn = module.devsecops_pipeline.github_oidc_provider_arn
  common_tags            = local.computed_tags
  git_commit_sha         = var.git_commit_sha
  resource_description   = var.resource_description
}

# =============================================================================
# Module 8: DevSecOps Pipeline
# =============================================================================
module "devsecops_pipeline" {
  source = "./modules/devsecops_pipeline"

  project_name          = var.project_name
  environment           = var.environment
  naming_prefix         = local.naming_prefix
  ecr_repository_prefix = var.ecr_repository_prefix
  ecr_scan_on_push      = var.ecr_scan_on_push
  ecr_immutable_tags    = var.ecr_immutable_tags
  ecr_lifecycle_count   = var.ecr_lifecycle_count
  enable_arc            = var.enable_arc
  arc_namespace         = var.arc_namespace
  arc_runner_replicas   = var.arc_runner_replicas
  cluster_name          = module.eks_platform.cluster_name
  oidc_provider_arn     = module.eks_platform.oidc_provider_arn
  vpc_id                = module.networking.vpc_id
  private_subnet_ids    = module.networking.private_subnet_ids
  common_tags           = local.computed_tags
  git_commit_sha        = var.git_commit_sha
  resource_description  = var.resource_description
}

# =============================================================================
# Module 9: Atlantis GitOps
# =============================================================================
module "atlantis_gitops" {
  source = "./modules/atlantis_gitops"

  project_name          = var.project_name
  environment           = var.environment
  naming_prefix         = local.naming_prefix
  atlantis_enabled      = var.atlantis_enabled
  atlantis_version      = var.atlantis_version
  atlantis_domain       = var.atlantis_domain
  atlantis_github_user  = var.atlantis_github_user
  atlantis_repo_whitelist = var.atlantis_repo_whitelist
  atlantis_dynamodb_table = var.atlantis_dynamodb_table
  cluster_name          = module.eks_platform.cluster_name
  oidc_provider_arn     = module.eks_platform.oidc_provider_arn
  vpc_id                = module.networking.vpc_id
  private_subnet_ids    = module.networking.private_subnet_ids
  common_tags           = local.computed_tags
  git_commit_sha        = var.git_commit_sha
  resource_description  = var.resource_description
}

# =============================================================================
# Module 10: Backstage IDP
# =============================================================================
module "backstage_idp" {
  source = "./modules/backstage_idp"

  project_name                   = var.project_name
  environment                    = var.environment
  naming_prefix                  = local.naming_prefix
  backstage_enabled              = var.backstage_enabled
  backstage_domain               = var.backstage_domain
  backstage_replicas             = var.backstage_replicas
  backstage_image_tag            = var.backstage_image_tag
  backstage_db_instance_class    = var.backstage_db_instance_class
  backstage_db_multi_az          = var.backstage_db_multi_az
  backstage_db_backup_retention  = var.backstage_db_backup_retention
  backstage_techdocs_bucket_prefix = var.backstage_techdocs_bucket_prefix
  keycloak_realm                 = var.keycloak_realm
  keycloak_client_id             = var.keycloak_client_id
  enable_keycloak_sso            = var.enable_keycloak_sso
  cluster_name                   = module.eks_platform.cluster_name
  oidc_provider_arn              = module.eks_platform.oidc_provider_arn
  vpc_id                         = module.networking.vpc_id
  private_subnet_ids             = module.networking.private_subnet_ids
  database_subnet_ids            = module.networking.database_subnet_ids
  common_tags                    = local.computed_tags
  git_commit_sha                 = var.git_commit_sha
  resource_description           = var.resource_description
}

# =============================================================================
# Module 11: Falco Runtime
# =============================================================================
module "falco_runtime" {
  source = "./modules/falco_runtime"

  project_name          = var.project_name
  environment           = var.environment
  naming_prefix         = local.naming_prefix
  falco_enabled         = var.falco_enabled
  falco_version         = var.falco_version
  falco_ebpf_enabled    = var.falco_ebpf_enabled
  falcosidekick_enabled = var.falcosidekick_enabled
  cluster_name          = module.eks_platform.cluster_name
  oidc_provider_arn     = module.eks_platform.oidc_provider_arn
  pagerduty_integration_key = var.pagerduty_integration_key
  common_tags           = local.computed_tags
  git_commit_sha        = var.git_commit_sha
  resource_description  = var.resource_description
}

# =============================================================================
# Module 12: Drift Detection
# =============================================================================
module "drift_detection" {
  source = "./modules/drift_detection"

  project_name             = var.project_name
  environment              = var.environment
  naming_prefix            = local.naming_prefix
  drift_detection_enabled  = var.drift_detection_enabled
  drift_check_interval     = var.drift_check_interval
  drift_auto_remediate     = var.drift_auto_remediate
  drift_notification_email = var.drift_notification_email
  terraform_state_bucket   = "nexus-platform-tfstate"
  terraform_state_key      = "terraform.tfstate"
  common_tags              = local.computed_tags
  git_commit_sha           = var.git_commit_sha
  resource_description     = var.resource_description
}

# =============================================================================
# Module 13: Rollback System
# =============================================================================
module "rollback_system" {
  source = "./modules/rollback_system"

  project_name               = var.project_name
  environment                = var.environment
  naming_prefix              = local.naming_prefix
  rollback_auto_staging      = var.rollback_auto_staging
  rollback_requires_approval = var.rollback_requires_approval
  github_token_secret_arn    = module.external_secrets.github_token_secret_arn
  common_tags                = local.computed_tags
  git_commit_sha             = var.git_commit_sha
  resource_description       = var.resource_description
}

# =============================================================================
# Module 14: SBOM Platform
# =============================================================================
module "sbom_platform" {
  source = "./modules/sbom_platform"

  project_name              = var.project_name
  environment               = var.environment
  naming_prefix             = local.naming_prefix
  dependency_track_enabled  = var.dependency_track_enabled
  dependency_track_domain   = var.dependency_track_domain
  dependency_track_db_class = var.dependency_track_db_class
  cluster_name              = module.eks_platform.cluster_name
  oidc_provider_arn         = module.eks_platform.oidc_provider_arn
  vpc_id                    = module.networking.vpc_id
  private_subnet_ids        = module.networking.private_subnet_ids
  database_subnet_ids       = module.networking.database_subnet_ids
  common_tags               = local.computed_tags
  git_commit_sha            = var.git_commit_sha
  resource_description      = var.resource_description
}

# =============================================================================
# Module 15: Policy Engine
# =============================================================================
module "policy_engine" {
  source = "./modules/policy_engine"

  project_name         = var.project_name
  environment          = var.environment
  naming_prefix        = local.naming_prefix
  common_tags          = local.computed_tags
  git_commit_sha       = var.git_commit_sha
  resource_description = var.resource_description
}

# =============================================================================
# Module 16: Cost Management
# =============================================================================
module "cost_management" {
  source = "./modules/cost_management"

  project_name         = var.project_name
  environment          = var.environment
  naming_prefix        = local.naming_prefix
  enable_kubecost      = var.enable_kubecost
  kubecost_domain      = var.kubecost_domain
  infracost_enabled    = var.infracost_enabled
  infracost_api_key    = var.infracost_api_key
  cost_centers         = var.cost_centers
  cluster_name         = module.eks_platform.cluster_name
  oidc_provider_arn    = module.eks_platform.oidc_provider_arn
  common_tags          = local.computed_tags
  git_commit_sha       = var.git_commit_sha
  resource_description = var.resource_description
}

# =============================================================================
# Module 17: Observability
# =============================================================================
module "observability_sec" {
  source = "./modules/observability_sec"

  project_name              = var.project_name
  environment               = var.environment
  naming_prefix             = local.naming_prefix
  enable_prometheus         = var.enable_prometheus
  enable_grafana            = var.enable_grafana
  grafana_domain            = var.grafana_domain
  grafana_admin_password    = var.grafana_admin_password
  pagerduty_integration_key = var.pagerduty_integration_key
  enable_cloudwatch_logs    = var.enable_cloudwatch_logs
  log_retention_days        = var.log_retention_days
  mttp_threshold_days       = var.mttp_threshold_days
  cluster_name              = module.eks_platform.cluster_name
  oidc_provider_arn         = module.eks_platform.oidc_provider_arn
  vpc_id                    = module.networking.vpc_id
  private_subnet_ids        = module.networking.private_subnet_ids
  common_tags               = local.computed_tags
  git_commit_sha            = var.git_commit_sha
  resource_description      = var.resource_description
}

# =============================================================================
# Module 18: Docs Generator
# =============================================================================
module "docs_generator" {
  source = "./modules/docs_generator"

  project_name         = var.project_name
  environment          = var.environment
  naming_prefix        = local.naming_prefix
  common_tags          = local.computed_tags
  git_commit_sha       = var.git_commit_sha
  resource_description = var.resource_description
}

# =============================================================================
# Module 19: Audit Logging
# =============================================================================
module "audit_logging" {
  source = "./modules/audit_logging"

  project_name             = var.project_name
  environment              = var.environment
  naming_prefix            = local.naming_prefix
  enable_cloudtrail        = var.enable_cloudtrail
  cloudtrail_bucket_prefix = var.cloudtrail_bucket_prefix
  audit_retention_years    = var.audit_retention_years
  enable_mfa_delete        = var.enable_mfa_delete
  aws_secondary_region     = var.aws_secondary_region
  common_tags              = local.computed_tags
  git_commit_sha           = var.git_commit_sha
  resource_description     = var.resource_description
}

# =============================================================================
# Module 20: Golden Path Factory
# =============================================================================
module "golden_path_factory" {
  source = "./modules/golden_path_factory"

  project_name         = var.project_name
  environment          = var.environment
  naming_prefix        = local.naming_prefix
  cluster_name         = module.eks_platform.cluster_name
  oidc_provider_arn    = module.eks_platform.oidc_provider_arn
  vpc_id               = module.networking.vpc_id
  private_subnet_ids   = module.networking.private_subnet_ids
  database_subnet_ids  = module.networking.database_subnet_ids
  cost_centers         = var.cost_centers
  common_tags          = local.computed_tags
  git_commit_sha       = var.git_commit_sha
  resource_description = var.resource_description
}
