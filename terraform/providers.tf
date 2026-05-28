provider "aws" {
  region              = var.aws_region
  profile             = var.aws_profile
  allowed_account_ids = var.allowed_account_ids

  default_tags {
    tags = merge(var.common_tags, {
      Environment = var.environment
      GitCommit   = var.git_commit_sha
      Description = var.resource_description
    })
  }
}

provider "aws" {
  alias               = "secondary"
  region              = var.aws_secondary_region
  profile             = var.aws_profile
  allowed_account_ids = var.allowed_account_ids

  default_tags {
    tags = merge(var.common_tags, {
      Environment = var.environment
      GitCommit   = var.git_commit_sha
      Description = var.resource_description
    })
  }
}

provider "kubernetes" {
  host                   = module.eks_platform.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks_platform.cluster_ca_certificate)
  token                  = data.aws_eks_cluster_auth.this.token
}

provider "helm" {
  kubernetes {
    host                   = module.eks_platform.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks_platform.cluster_ca_certificate)
    token                  = data.aws_eks_cluster_auth.this.token
  }
}

provider "github" {
  token = data.aws_secretsmanager_secret_version.github_token.secret_string
}
