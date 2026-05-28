# =============================================================================
# Golden Path Infrastructure Template
# Teams call this module to provision standard infrastructure for a microservice.
# =============================================================================

locals {
  service_prefix = "${var.team_name}-${var.service_name}"
}

# ------------------------------------------------------------------------------
# Microservice Namespace
# ------------------------------------------------------------------------------
module "microservice_namespace" {
  source = "../../../terraform/modules/golden_path_factory/microservice_namespace"

  namespace_name  = local.service_prefix
  team_label      = var.team_name
  cost_center     = var.cost_center
  environment     = var.environment
  resource_limits = var.resource_limits
}

# ------------------------------------------------------------------------------
# Microservice RDS (optional)
# ------------------------------------------------------------------------------
module "microservice_rds" {
  count  = var.enable_database ? 1 : 0
  source = "../../../terraform/modules/golden_path_factory/microservice_rds"

  instance_name       = local.service_prefix
  environment         = var.environment
  vpc_id              = var.vpc_id
  database_subnet_ids = var.database_subnet_ids
  instance_class      = var.db_instance_class
  multi_az            = var.db_multi_az
}

# ------------------------------------------------------------------------------
# Microservice SQS (optional)
# ------------------------------------------------------------------------------
module "microservice_sqs" {
  count  = var.enable_queue ? 1 : 0
  source = "../../../terraform/modules/golden_path_factory/microservice_sqs"

  queue_name  = local.service_prefix
  environment = var.environment
}

# ------------------------------------------------------------------------------
# Microservice S3 (optional)
# ------------------------------------------------------------------------------
module "microservice_s3" {
  count  = var.enable_storage ? 1 : 0
  source = "../../../terraform/modules/golden_path_factory/microservice_s3"

  bucket_prefix = local.service_prefix
  environment   = var.environment
}

# ------------------------------------------------------------------------------
# Microservice IRSA
# ------------------------------------------------------------------------------
module "microservice_irsa" {
  source = "../../../terraform/modules/golden_path_factory/microservice_irsa"

  role_name         = local.service_prefix
  namespace         = local.service_prefix
  service_account   = local.service_prefix
  oidc_provider_arn = var.oidc_provider_arn
  environment       = var.environment
}
