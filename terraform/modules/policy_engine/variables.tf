variable "project_name" { type = string }
variable "environment" { type = string }
variable "naming_prefix" { type = string }
variable "common_tags" { type = map(string) }
variable "git_commit_sha" { type = string }
variable "resource_description" { type = string }
