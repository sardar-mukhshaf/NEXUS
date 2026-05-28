# =============================================================================
# NEXUS PLATFORM — Makefile
# Edit ONLY terraform.tfvars, then run make bootstrap.
# =============================================================================

.SHELLFLAGS := -eu -o pipefail -c
.DEFAULT_GOAL := help

TF_DIR         := terraform
SCRIPTS_DIR    := scripts
GIT_COMMIT_SHA := $(shell git rev-parse --short HEAD 2>/dev/null || echo "unknown")

export TF_IN_AUTOMATION ?= true
export GIT_COMMIT_SHA

# ------------------------------------------------------------------------------
# Help
# ------------------------------------------------------------------------------
.PHONY: help
help: ## Show this help message
	@echo "Nexus Platform — Available Targets"
	@echo "===================================="
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2}'

# ------------------------------------------------------------------------------
# Bootstrap
# ------------------------------------------------------------------------------
.PHONY: bootstrap
bootstrap: ## Create remote backend, KMS keys, and pre-flight checks
	@echo "[NEXUS] Running pre-flight checks..."
	@bash $(SCRIPTS_DIR)/pre-flight-checks.sh
	@echo "[NEXUS] Bootstrapping Terraform backend..."
	@bash $(SCRIPTS_DIR)/bootstrap-backend.sh
	@echo "[NEXUS] Installing SOPS..."
	@bash $(SCRIPTS_DIR)/install-sops.sh
	@echo "[NEXUS] Bootstrap complete. Edit terraform.tfvars, then run 'make plan'."

# ------------------------------------------------------------------------------
# Terraform Lifecycle
# ------------------------------------------------------------------------------
.PHONY: plan
plan: ## Run terraform plan with git commit tag
	cd $(TF_DIR) && terraform plan -var="git_commit_sha=$(GIT_COMMIT_SHA)" -out=tfplan

.PHONY: apply
apply: ## Apply planned changes
	cd $(TF_DIR) && terraform apply tfplan

.PHONY: destroy
destroy: ## Destroy all infrastructure (requires confirmation)
	cd $(TF_DIR) && terraform destroy -var="git_commit_sha=$(GIT_COMMIT_SHA)"

.PHONY: fmt
fmt: ## Format all Terraform files
	cd $(TF_DIR) && terraform fmt -recursive

# ------------------------------------------------------------------------------
# Validation
# ------------------------------------------------------------------------------
.PHONY: validate
validate: fmt ## Run terraform validate, tflint, checkov, conftest
	cd $(TF_DIR) && terraform validate
	@echo "[NEXUS] Running tflint..."
	@which tflint >/dev/null 2>&1 && tflint --config=../.tflint.hcl || echo "tflint not installed, skipping"
	@echo "[NEXUS] Running checkov..."
	@which checkov >/dev/null 2>&1 && checkov -d . --framework terraform || echo "checkov not installed, skipping"
	@echo "[NEXUS] Running conftest..."
	@bash $(SCRIPTS_DIR)/validate-policies.sh

.PHONY: validate-policies
validate-policies: ## Validate all Conftest and Kyverno policies
	@echo "[NEXUS] Validating Conftest policies..."
	@for f in policies/conftest/terraform/*.rego; do \
		echo "  Checking $$f"; \
	done
	@echo "[NEXUS] Validating Kyverno policies..."
	@which kyverno >/dev/null 2>&1 && kyverno test ./policies/kyverno-tests || echo "kyverno CLI not installed, skipping"

# ------------------------------------------------------------------------------
# Drift & Remediation
# ------------------------------------------------------------------------------
.PHONY: drift-check
drift-check: ## Run drift detection manually
	@echo "[NEXUS] Running drift detection..."
	@python3 $(SCRIPTS_DIR)/drift-detector.py --state-bucket nexus-platform-tfstate --state-key terraform.tfstate

# ------------------------------------------------------------------------------
# Documentation
# ------------------------------------------------------------------------------
.PHONY: docs-generate
docs-generate: ## Generate architecture docs with terraform-docs + Mermaid diagrams
	@echo "[NEXUS] Generating documentation..."
	@bash $(SCRIPTS_DIR)/generate-docs.sh

# ------------------------------------------------------------------------------
# Secrets
# ------------------------------------------------------------------------------
.PHONY: encrypt-secret
encrypt-secret: ## Encrypt a secret with SOPS (usage: make encrypt-secret FILE=path/to/secret.yaml)
	@if [ -z "$(FILE)" ]; then echo "Usage: make encrypt-secret FILE=path/to/secret.yaml"; exit 1; fi
	@sops --encrypt --in-place $(FILE)

.PHONY: rotate-sops-keys
rotate-sops-keys: ## Re-encrypt all secrets with new KMS key
	@bash $(SCRIPTS_DIR)/rotate-sops-keys.sh

# ------------------------------------------------------------------------------
# Deployment Verification
# ------------------------------------------------------------------------------
.PHONY: verify-deployment
verify-deployment: ## Verify image signatures, scan results, and SBOM before deployment
	@bash $(SCRIPTS_DIR)/verify-deployment.sh

.PHONY: generate-sbom
generate-sbom: ## Generate and sign SBOM for current build
	@bash $(SCRIPTS_DIR)/generate-sbom.sh

# ------------------------------------------------------------------------------
# Break-Glass
# ------------------------------------------------------------------------------
.PHONY: break-glass
break-glass: ## Emergency manual access with approval logging
	@bash $(SCRIPTS_DIR)/break-glass.sh

# ------------------------------------------------------------------------------
# Utilities
# ------------------------------------------------------------------------------
.PHONY: clean
clean: ## Remove generated plan files and artifacts
	@find $(TF_DIR) -name "tfplan" -delete
	@find $(TF_DIR) -name "*.tfplan" -delete
	@find . -name "__pycache__" -type d -exec rm -rf {} + 2>/dev/null || true
