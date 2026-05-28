terraform {
  required_version = ">= 1.7.0"

  backend "s3" {
    bucket         = "nexus-platform-tfstate"
    key            = "terraform.tfstate"
    region         = "eu-west-1"
    encrypt        = true
    dynamodb_table = "nexus-platform-tfstate-lock"
    kms_key_id     = "alias/nexus-tfstate"
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.12"
    }
    github = {
      source  = "integrations/github"
      version = "~> 5.0"
    }
  }
}
