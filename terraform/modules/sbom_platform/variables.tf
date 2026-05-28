variable "project_name" { type = string }
variable "environment" { type = string }
variable "naming_prefix" { type = string }
variable "dependency_track_enabled" { type = bool }
variable "dependency_track_domain" { type = string }
variable "dependency_track_db_class" { type = string }
variable "cluster_name" { type = string }
variable "oidc_provider_arn" { type = string }
variable "oidc_provider_url" { type = string }
variable "vpc_id" { type = string }
variable "private_subnet_ids" { type = list(string) }
variable "database_subnet_ids" { type = list(string) }
variable "vpc_cidr" { type = string default = "10.0.0.0/16" }
variable "common_tags" { type = map(string) }
variable "git_commit_sha" { type = string }
variable "resource_description" { type = string }
