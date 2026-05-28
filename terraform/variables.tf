# =============================================================================
# NEXUS PLATFORM — GLOBAL VARIABLES
# Every variable MUST have description, type, and validation where applicable.
# =============================================================================

# ------------------------------------------------------------------------------
# Project Metadata
# ------------------------------------------------------------------------------
variable "project_name" {
  description = "Project name used as prefix for all resources"
  type        = string
  default     = "nexus"

  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.project_name))
    error_message = "project_name must contain only lowercase letters, numbers, and hyphens."
  }
}

variable "environment" {
  description = "Deployment environment"
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment must be one of: dev, staging, prod."
  }
}

variable "git_commit_sha" {
  description = "Git commit SHA to tag resources with"
  type        = string
  default     = "unknown"

  validation {
    condition     = can(regex("^[a-f0-9]{7,40}$", var.git_commit_sha)) || var.git_commit_sha == "unknown"
    error_message = "git_commit_sha must be a valid Git SHA (7-40 hex characters)."
  }
}

variable "git_repository_url" {
  description = "URL of the Git repository managing this infrastructure"
  type        = string
  default     = ""
}

variable "resource_description" {
  description = "Human-readable description applied to all resources"
  type        = string
  default     = "Nexus IDP managed infrastructure resource"

  validation {
    condition     = length(var.resource_description) >= 10
    error_message = "resource_description must be at least 10 characters."
  }
}

variable "security_level" {
  description = "Security hardening level: standard, hardened, or maximum"
  type        = string
  default     = "hardened"

  validation {
    condition     = contains(["standard", "hardened", "maximum"], var.security_level)
    error_message = "security_level must be one of: standard, hardened, maximum."
  }
}

# ------------------------------------------------------------------------------
# AWS Settings
# ------------------------------------------------------------------------------
variable "aws_region" {
  description = "Primary AWS region"
  type        = string
  default     = "eu-west-1"
}

variable "aws_secondary_region" {
  description = "Secondary AWS region for disaster recovery"
  type        = string
  default     = "eu-central-1"
}

variable "aws_profile" {
  description = "AWS CLI profile name"
  type        = string
  default     = ""
}

variable "allowed_account_ids" {
  description = "Allowed AWS account IDs"
  type        = list(string)
  default     = []
}

# ------------------------------------------------------------------------------
# Networking
# ------------------------------------------------------------------------------
variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"

  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "vpc_cidr must be a valid CIDR block."
  }
}

variable "availability_zones" {
  description = "List of availability zones"
  type        = list(string)
  default     = []
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets"
  type        = list(string)
  default     = []
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets"
  type        = list(string)
  default     = []
}

variable "database_subnet_cidrs" {
  description = "CIDR blocks for database subnets"
  type        = list(string)
  default     = []
}

variable "enable_nat_gateway" {
  description = "Enable NAT Gateway"
  type        = bool
  default     = true
}

variable "single_nat_gateway" {
  description = "Use a single NAT Gateway (cheaper, less HA)"
  type        = bool
  default     = false
}

variable "enable_vpn_gateway" {
  description = "Enable VPN Gateway"
  type        = bool
  default     = false
}

variable "enable_flow_logs" {
  description = "Enable VPC Flow Logs"
  type        = bool
  default     = true
}

variable "flow_logs_retention_days" {
  description = "VPC Flow Logs retention in days"
  type        = number
  default     = 2555
}

variable "enable_vpc_endpoints" {
  description = "List of VPC endpoints to create"
  type        = list(string)
  default     = []
}

# ------------------------------------------------------------------------------
# EKS Platform
# ------------------------------------------------------------------------------
variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
  default     = "nexus-platform"
}

variable "cluster_version" {
  description = "EKS Kubernetes version"
  type        = string
  default     = "1.29"
}

variable "cluster_endpoint_public_access" {
  description = "Enable public EKS endpoint"
  type        = bool
  default     = true
}

variable "cluster_endpoint_private_access" {
  description = "Enable private EKS endpoint"
  type        = bool
  default     = true
}

variable "node_groups" {
  description = "Map of EKS managed node group configurations"
  type = map(object({
    desired_size   = number
    min_size       = number
    max_size       = number
    instance_types = list(string)
    capacity_type  = string
    disk_size      = number
    labels         = map(string)
    taints = list(object({
      key    = string
      value  = string
      effect = string
    }))
  }))
  default = {}
}

variable "fargate_profiles" {
  description = "Map of Fargate profile configurations"
  type = map(object({
    selectors = list(object({
      namespace = string
      labels    = optional(map(string), {})
    }))
  }))
  default = {}
}

variable "cluster_pod_security_standard" {
  description = "EKS Pod Security Standard to enforce"
  type        = string
  default     = "restricted"
}

variable "enable_guardduty" {
  description = "Enable GuardDuty for EKS"
  type        = bool
  default     = true
}

variable "enable_security_hub" {
  description = "Enable AWS Security Hub"
  type        = bool
  default     = true
}

# ------------------------------------------------------------------------------
# Backstage IDP
# ------------------------------------------------------------------------------
variable "backstage_enabled" {
  description = "Enable Backstage IDP"
  type        = bool
  default     = true
}

variable "backstage_domain" {
  description = "Domain for Backstage"
  type        = string
  default     = ""
}

variable "backstage_replicas" {
  description = "Number of Backstage replicas"
  type        = number
  default     = 2
}

variable "backstage_image_tag" {
  description = "Backstage container image tag"
  type        = string
  default     = "1.22.0"
}

variable "backstage_db_instance_class" {
  description = "RDS instance class for Backstage"
  type        = string
  default     = "db.r6g.large"
}

variable "backstage_db_multi_az" {
  description = "Enable Multi-AZ for Backstage RDS"
  type        = bool
  default     = true
}

variable "backstage_db_backup_retention" {
  description = "Backstage RDS backup retention in days"
  type        = number
  default     = 7
}

variable "backstage_techdocs_bucket_prefix" {
  description = "S3 bucket prefix for TechDocs"
  type        = string
  default     = "nexus-techdocs"
}

variable "keycloak_realm" {
  description = "Keycloak realm for SSO"
  type        = string
  default     = "platform-engineering"
}

variable "keycloak_client_id" {
  description = "Keycloak client ID for Backstage"
  type        = string
  default     = "backstage"
}

variable "enable_keycloak_sso" {
  description = "Enable Keycloak SSO integration"
  type        = bool
  default     = true
}

# ------------------------------------------------------------------------------
# ArgoCD
# ------------------------------------------------------------------------------
variable "argocd_enabled" {
  description = "Enable ArgoCD"
  type        = bool
  default     = true
}

variable "argocd_version" {
  description = "ArgoCD Helm chart version"
  type        = string
  default     = "2.10.0"
}

variable "argocd_domain" {
  description = "Domain for ArgoCD"
  type        = string
  default     = ""
}

variable "argocd_admin_enabled" {
  description = "Enable local admin user"
  type        = bool
  default     = false
}

variable "argocd_sso_enabled" {
  description = "Enable SSO for ArgoCD"
  type        = bool
  default     = true
}

variable "argocd_self_heal" {
  description = "Enable ArgoCD self-healing"
  type        = bool
  default     = true
}

variable "argocd_prune" {
  description = "Enable ArgoCD pruning"
  type        = bool
  default     = true
}

# ------------------------------------------------------------------------------
# Atlantis GitOps
# ------------------------------------------------------------------------------
variable "atlantis_enabled" {
  description = "Enable Atlantis"
  type        = bool
  default     = true
}

variable "atlantis_version" {
  description = "Atlantis container version"
  type        = string
  default     = "0.27.0"
}

variable "atlantis_domain" {
  description = "Domain for Atlantis"
  type        = string
  default     = ""
}

variable "atlantis_github_user" {
  description = "GitHub user for Atlantis"
  type        = string
  default     = ""
}

variable "atlantis_repo_whitelist" {
  description = "GitHub repository whitelist for Atlantis"
  type        = list(string)
  default     = []
}

variable "atlantis_dynamodb_table" {
  description = "DynamoDB table for Atlantis locks"
  type        = string
  default     = "nexus-atlantis-locks"
}

# ------------------------------------------------------------------------------
# Security Tooling
# ------------------------------------------------------------------------------
variable "kyverno_enabled" {
  description = "Enable Kyverno"
  type        = bool
  default     = true
}

variable "kyverno_version" {
  description = "Kyverno Helm chart version"
  type        = string
  default     = "3.2.0"
}

variable "kyverno_policies_enforce" {
  description = "Enforce Kyverno policies"
  type        = bool
  default     = true
}

variable "falco_enabled" {
  description = "Enable Falco runtime security"
  type        = bool
  default     = true
}

variable "falco_version" {
  description = "Falco Helm chart version"
  type        = string
  default     = "0.37.0"
}

variable "falco_ebpf_enabled" {
  description = "Enable eBPF probe for Falco"
  type        = bool
  default     = true
}

variable "falcosidekick_enabled" {
  description = "Enable Falcosidekick alerting"
  type        = bool
  default     = true
}

variable "enable_cosign_kms" {
  description = "Enable Cosign KMS signing"
  type        = bool
  default     = true
}

variable "cosign_kms_key_alias" {
  description = "KMS key alias for Cosign"
  type        = string
  default     = "alias/nexus-cosign"
}

variable "enable_keyless_signing" {
  description = "Enable Cosign keyless signing via OIDC"
  type        = bool
  default     = true
}

variable "external_secrets_enabled" {
  description = "Enable External Secrets Operator"
  type        = bool
  default     = true
}

variable "external_secrets_version" {
  description = "External Secrets Operator Helm version"
  type        = string
  default     = "0.9.0"
}

# ------------------------------------------------------------------------------
# DevSecOps Pipeline
# ------------------------------------------------------------------------------
variable "ecr_repository_prefix" {
  description = "Prefix for ECR repositories"
  type        = string
  default     = "nexus"
}

variable "ecr_scan_on_push" {
  description = "Enable ECR scan on push"
  type        = bool
  default     = true
}

variable "ecr_immutable_tags" {
  description = "Enable ECR immutable tags"
  type        = bool
  default     = true
}

variable "ecr_lifecycle_count" {
  description = "Number of images to retain in ECR"
  type        = number
  default     = 30
}

variable "enable_arc" {
  description = "Enable GitHub Actions Runner Controller"
  type        = bool
  default     = true
}

variable "arc_namespace" {
  description = "Namespace for ARC runners"
  type        = string
  default     = "arc-runners"
}

variable "arc_runner_replicas" {
  description = "Number of ARC runner replicas"
  type        = number
  default     = 2
}

# ------------------------------------------------------------------------------
# Observability
# ------------------------------------------------------------------------------
variable "enable_prometheus" {
  description = "Enable Prometheus"
  type        = bool
  default     = true
}

variable "enable_grafana" {
  description = "Enable Grafana"
  type        = bool
  default     = true
}

variable "grafana_domain" {
  description = "Domain for Grafana"
  type        = string
  default     = ""
}

variable "grafana_admin_password" {
  description = "Grafana admin password"
  type        = string
  default     = ""
  sensitive   = true
}

variable "pagerduty_integration_key" {
  description = "PagerDuty integration key"
  type        = string
  default     = ""
  sensitive   = true
}

variable "enable_cloudwatch_logs" {
  description = "Enable CloudWatch centralized logging"
  type        = bool
  default     = true
}

variable "log_retention_days" {
  description = "CloudWatch log retention in days"
  type        = number
  default     = 90
}

# ------------------------------------------------------------------------------
# Cost Management
# ------------------------------------------------------------------------------
variable "enable_kubecost" {
  description = "Enable Kubecost"
  type        = bool
  default     = true
}

variable "kubecost_domain" {
  description = "Domain for Kubecost"
  type        = string
  default     = ""
}

variable "infracost_enabled" {
  description = "Enable Infracost"
  type        = bool
  default     = true
}

variable "infracost_api_key" {
  description = "Infracost API key"
  type        = string
  default     = ""
  sensitive   = true
}

variable "cost_centers" {
  description = "Map of team names to cost center labels"
  type        = map(string)
  default     = {}
}

# ------------------------------------------------------------------------------
# Drift Detection
# ------------------------------------------------------------------------------
variable "drift_detection_enabled" {
  description = "Enable drift detection Lambda"
  type        = bool
  default     = true
}

variable "drift_check_interval" {
  description = "EventBridge rate expression for drift checks"
  type        = string
  default     = "rate(15 minutes)"
}

variable "drift_auto_remediate" {
  description = "Auto-trigger Atlantis plan on drift detection"
  type        = bool
  default     = false
}

variable "drift_notification_email" {
  description = "Email for drift alerts"
  type        = string
  default     = ""
}

# ------------------------------------------------------------------------------
# Rollback System
# ------------------------------------------------------------------------------
variable "rollback_auto_staging" {
  description = "Auto-revert staging on sync failure"
  type        = bool
  default     = true
}

variable "rollback_requires_approval" {
  description = "Require approval before rollback in prod"
  type        = bool
  default     = true
}

# ------------------------------------------------------------------------------
# SBOM Platform
# ------------------------------------------------------------------------------
variable "dependency_track_enabled" {
  description = "Enable Dependency-Track"
  type        = bool
  default     = true
}

variable "dependency_track_domain" {
  description = "Domain for Dependency-Track"
  type        = string
  default     = ""
}

variable "dependency_track_db_class" {
  description = "RDS instance class for Dependency-Track"
  type        = string
  default     = "db.r6g.large"
}

# ------------------------------------------------------------------------------
# Audit & Compliance
# ------------------------------------------------------------------------------
variable "enable_cloudtrail" {
  description = "Enable CloudTrail"
  type        = bool
  default     = true
}

variable "cloudtrail_bucket_prefix" {
  description = "S3 bucket prefix for CloudTrail logs"
  type        = string
  default     = "nexus-cloudtrail"
}

variable "audit_retention_years" {
  description = "Audit log retention in years"
  type        = number
  default     = 7
}

variable "enable_mfa_delete" {
  description = "Enable MFA delete on audit buckets"
  type        = bool
  default     = true
}

variable "compliance_framework" {
  description = "Compliance framework identifier"
  type        = string
  default     = "financial-sector-cybersecurity-framework"
}

variable "data_protection_regulation" {
  description = "Data protection regulation identifier"
  type        = string
  default     = "data-protection-regulation"
}

# ------------------------------------------------------------------------------
# Secrets Management
# ------------------------------------------------------------------------------
variable "sops_enabled" {
  description = "Enable SOPS for Git encryption"
  type        = bool
  default     = true
}

variable "sops_kms_key_arn_dev" {
  description = "KMS key ARN for dev SOPS encryption"
  type        = string
  default     = ""
}

variable "sops_kms_key_arn_prod" {
  description = "KMS key ARN for prod SOPS encryption"
  type        = string
  default     = ""
}

# ------------------------------------------------------------------------------
# MTTP & Policy Thresholds
# ------------------------------------------------------------------------------
variable "mttp_threshold_days" {
  description = "Maximum allowed MTTP in days"
  type        = number
  default     = 7

  validation {
    condition     = var.mttp_threshold_days > 0 && var.mttp_threshold_days < 30
    error_message = "mttp_threshold_days must be between 1 and 29."
  }
}

variable "mttp_critical_threshold" {
  description = "MTTP threshold for critical CVEs"
  type        = number
  default     = 3
}

variable "mttp_high_threshold" {
  description = "MTTP threshold for high CVEs"
  type        = number
  default     = 7
}

variable "max_allowed_critical_cves" {
  description = "Maximum allowed critical CVEs in deployment"
  type        = number
  default     = 0
}

variable "max_allowed_high_cves" {
  description = "Maximum allowed high CVEs in deployment"
  type        = number
  default     = 5
}

# ------------------------------------------------------------------------------
# Common Tags
# ------------------------------------------------------------------------------
variable "common_tags" {
  description = "Common tags applied to all resources"
  type        = map(string)
  default = {
    Project    = "nexus"
    ManagedBy  = "terraform"
    Repository = "nexus-platform"
    Owner      = "platform-engineering"
    CostCenter = "platform"
  }
}
