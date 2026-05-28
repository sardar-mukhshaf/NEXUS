# =============================================================================
# NEXUS PLATFORM — SINGLE SOURCE OF TRUTH
# Edit ONLY this file (plus env-specific *.tfvars) to customize the platform.
# =============================================================================

# ------------------------------------------------------------------------------
# 1. Project Metadata
# ------------------------------------------------------------------------------
project_name = "nexus"
environment  = "dev"

# Git metadata injected at plan/apply time
git_commit_sha       = "unknown"
git_repository_url   = "https://github.com/example-org/nexus-platform"
resource_description = "Nexus IDP managed infrastructure resource"

# Security classification: standard | hardened | maximum
security_level = "hardened"

# ------------------------------------------------------------------------------
# 2. AWS Settings
# ------------------------------------------------------------------------------
aws_region              = "eu-west-1"
aws_secondary_region    = "eu-central-1"
aws_profile             = "nexus-platform"
allowed_account_ids     = ["123456789012"]

# ------------------------------------------------------------------------------
# 3. Networking
# ------------------------------------------------------------------------------
vpc_cidr           = "10.0.0.0/16"
availability_zones = ["eu-west-1a", "eu-west-1b", "eu-west-1c"]

# Subnet sizing: /20 per tier per AZ (~4k IPs each)
public_subnet_cidrs   = ["10.0.0.0/20", "10.0.16.0/20", "10.0.32.0/20"]
private_subnet_cidrs  = ["10.0.48.0/20", "10.0.64.0/20", "10.0.80.0/20"]
database_subnet_cidrs = ["10.0.96.0/20", "10.0.112.0/20", "10.0.128.0/20"]

# NAT Gateway: one per AZ for high availability
enable_nat_gateway     = true
single_nat_gateway     = false
enable_vpn_gateway     = false
enable_flow_logs       = true
flow_logs_retention_days = 2555  # ~7 years

# VPC Endpoints (reduce data transfer + improve security)
enable_vpc_endpoints = ["s3", "ecr-api", "ecr-dkr", "secretsmanager", "logs", "sts", "ec2", "cloudwatch"]

# ------------------------------------------------------------------------------
# 4. EKS Platform
# ------------------------------------------------------------------------------
cluster_name       = "nexus-platform"
cluster_version    = "1.29"
cluster_endpoint_public_access  = true
cluster_endpoint_private_access = true

# Managed Node Groups
node_groups = {
  system = {
    desired_size   = 2
    min_size       = 2
    max_size       = 6
    instance_types = ["m6i.xlarge"]
    capacity_type  = "ON_DEMAND"
    disk_size      = 100
    labels = {
      workload-type = "system"
      cost-center   = "platform"
    }
    taints = []
  }
  workloads = {
    desired_size   = 3
    min_size       = 2
    max_size       = 20
    instance_types = ["m6i.2xlarge", "m5.2xlarge"]
    capacity_type  = "SPOT"
    disk_size      = 100
    labels = {
      workload-type = "workloads"
      cost-center   = "shared"
    }
    taints = []
  }
}

# Fargate profiles for serverless workloads
fargate_profiles = {
  kube_system = {
    selectors = [
      { namespace = "kube-system" }
    ]
  }
}

# Pod Security Standards
cluster_pod_security_standard = "restricted"

# GuardDuty + Security Hub
enable_guardduty    = true
enable_security_hub = true

# ------------------------------------------------------------------------------
# 5. Backstage IDP
# ------------------------------------------------------------------------------
backstage_enabled       = true
backstage_domain        = "backstage.nexus-platform.local"
backstage_replicas      = 2
backstage_image_tag     = "1.22.0"
backstage_db_instance_class = "db.r6g.large"
backstage_db_multi_az   = true
backstage_db_backup_retention = 7

# S3 TechDocs
backstage_techdocs_bucket_prefix = "nexus-techdocs"

# SSO via Keycloak
keycloak_realm          = "platform-engineering"
keycloak_client_id      = "backstage"
enable_keycloak_sso     = true

# ------------------------------------------------------------------------------
# 6. ArgoCD
# ------------------------------------------------------------------------------
argocd_enabled          = true
argocd_version          = "2.10.0"
argocd_domain           = "argocd.nexus-platform.local"
argocd_admin_enabled    = false
argocd_sso_enabled      = true

# Self-healing and pruning
argocd_self_heal        = true
argocd_prune            = true

# ------------------------------------------------------------------------------
# 7. Atlantis GitOps
# ------------------------------------------------------------------------------
atlantis_enabled        = true
atlantis_version        = "0.27.0"
atlantis_domain         = "atlantis.nexus-platform.local"
atlantis_github_user    = "nexus-atlantis"
atlantis_repo_whitelist = ["github.com/example-org/*"]
atlantis_dynamodb_table = "nexus-atlantis-locks"

# ------------------------------------------------------------------------------
# 8. Security Tooling
# ------------------------------------------------------------------------------
# Kyverno
kyverno_enabled         = true
kyverno_version         = "3.2.0"
kyverno_policies_enforce = true

# Falco
falco_enabled           = true
falco_version           = "0.37.0"
falco_ebpf_enabled      = true
falcosidekick_enabled   = true

# Cosign / Signing
enable_cosign_kms       = true
cosign_kms_key_alias    = "alias/nexus-cosign"
enable_keyless_signing  = true

# External Secrets
external_secrets_enabled = true
external_secrets_version = "0.9.0"

# ------------------------------------------------------------------------------
# 9. DevSecOps Pipeline
# ------------------------------------------------------------------------------
# ECR repositories will be created per microservice pattern
ecr_repository_prefix   = "nexus"
ecr_scan_on_push        = true
ecr_immutable_tags      = true
ecr_lifecycle_count     = 30

# GitHub Actions Runner Controller
enable_arc              = true
arc_namespace           = "arc-runners"
arc_runner_replicas     = 2

# ------------------------------------------------------------------------------
# 10. Observability
# ------------------------------------------------------------------------------
enable_prometheus       = true
enable_grafana          = true
grafana_domain          = "grafana.nexus-platform.local"
grafana_admin_password  = "CHANGE_ME_IN_SOPS"

# PagerDuty integration key (store real value in SOPS)
pagerduty_integration_key = "dummy-key-replace-in-sops"

# CloudWatch centralized logging
enable_cloudwatch_logs  = true
log_retention_days      = 90

# ------------------------------------------------------------------------------
# 11. Cost Management
# ------------------------------------------------------------------------------
enable_kubecost         = true
kubecost_domain         = "kubecost.nexus-platform.local"
infracost_enabled       = true
infracost_api_key       = "dummy-key-replace-in-sops"

# Team cost centers for allocation
cost_centers = {
  team-platform = "platform-engineering"
  team-backend  = "backend-squad"
  team-data     = "data-platform"
  team-frontend = "frontend-guild"
}

# ------------------------------------------------------------------------------
# 12. Drift Detection
# ------------------------------------------------------------------------------
drift_detection_enabled   = true
drift_check_interval      = "rate(15 minutes)"
drift_auto_remediate      = false  # true = auto-trigger Atlantis plan
drift_notification_email  = "platform-alerts@example.com"

# ------------------------------------------------------------------------------
# 13. Rollback System
# ------------------------------------------------------------------------------
rollback_auto_staging     = true
rollback_requires_approval = true

# ------------------------------------------------------------------------------
# 14. SBOM Platform
# ------------------------------------------------------------------------------
dependency_track_enabled  = true
dependency_track_domain   = "dependency-track.nexus-platform.local"
dependency_track_db_class = "db.r6g.large"

# ------------------------------------------------------------------------------
# 15. Audit & Compliance
# ------------------------------------------------------------------------------
enable_cloudtrail         = true
cloudtrail_bucket_prefix  = "nexus-cloudtrail"
audit_retention_years     = 7
enable_mfa_delete         = true

# Compliance framework mapping (generic)
compliance_framework = "financial-sector-cybersecurity-framework"
data_protection_regulation = "data-protection-regulation"

# ------------------------------------------------------------------------------
# 16. Secrets Management (SOPS)
# ------------------------------------------------------------------------------
sops_enabled              = true
sops_kms_key_arn_dev      = "arn:aws:kms:eu-west-1:123456789012:key/REPLACE-ME"
sops_kms_key_arn_prod     = "arn:aws:kms:eu-west-1:123456789012:key/REPLACE-ME"

# ------------------------------------------------------------------------------
# 17. MTTP & Policy Thresholds
# ------------------------------------------------------------------------------
mttp_threshold_days       = 7
mttp_critical_threshold   = 3
mttp_high_threshold       = 7
max_allowed_critical_cves = 0
max_allowed_high_cves     = 5

# ------------------------------------------------------------------------------
# 18. Common Tags (merged into every resource)
# ------------------------------------------------------------------------------
common_tags = {
  Project     = "nexus"
  ManagedBy   = "terraform"
  Repository  = "nexus-platform"
  Owner       = "platform-engineering"
  CostCenter  = "platform"
}
