variable "project_name" { type = string }
variable "environment" { type = string }
variable "naming_prefix" { type = string }
variable "falco_enabled" { type = bool }
variable "falco_version" { type = string }
variable "falco_ebpf_enabled" { type = bool }
variable "falcosidekick_enabled" { type = bool }
variable "cluster_name" { type = string }
variable "oidc_provider_arn" { type = string }
variable "oidc_provider_url" { type = string }
variable "pagerduty_integration_key" { type = string }
variable "slack_webhook_url" { type = string default = "" }
variable "common_tags" { type = map(string) }
variable "git_commit_sha" { type = string }
variable "resource_description" { type = string }
