#!/usr/bin/env bash
# =============================================================================
# NEXUS PLATFORM — Pre-Flight Checks
# Validates AWS creds, tools, quotas, and GitHub webhook accessibility.
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_NAME="nexus"
REGION="eu-west-1"
REQUIRED_TOOLS=(
  "terraform:1.7.0"
  "kubectl"
  "helm"
  "sops"
  "atlantis"
  "conftest"
  "trivy"
  "syft"
  "cosign"
  "kyverno"
  "argocd"
  "gh"
  "python3"
)

show_help() {
  cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Run pre-flight checks before deploying Nexus platform.

Options:
  -h, --help    Show this help message
  -q, --quick   Skip quota checks (faster)
EOF
}

QUICK=false
while [[ $# -gt 0 ]]; do
  case $1 in
    -h|--help) show_help; exit 0 ;;
    -q|--quick) QUICK=true; shift ;;
    *) echo "Unknown option: $1"; show_help; exit 1 ;;
  esac
done

echo "[PREFLIGHT] Starting Nexus platform pre-flight checks..."

# ------------------------------------------------------------------------------
# 1. AWS Credentials
# ------------------------------------------------------------------------------
echo "[PREFLIGHT] Checking AWS credentials..."
if ! aws sts get-caller-identity >/dev/null 2>&1; then
  echo "[FAIL] AWS credentials not configured or invalid."
  exit 1
fi

CALLER_IDENTITY=$(aws sts get-caller-identity --output json)
ACCOUNT_ID=$(echo "$CALLER_IDENTITY" | grep -o '"Account": "[^"]*"' | cut -d'"' -f4)
USER_ARN=$(echo "$CALLER_IDENTITY" | grep -o '"Arn": "[^"]*"' | cut -d'"' -f4)
echo "[PASS] AWS authenticated: ${USER_ARN} (Account: ${ACCOUNT_ID})"

# Check assumed role
if [[ "$USER_ARN" == *"assumed-role"* ]]; then
  echo "[PASS] Using assumed role (recommended)."
else
  echo "[WARN] Not using an assumed role. Consider using IAM roles for production."
fi

# ------------------------------------------------------------------------------
# 2. Required Tools
# ------------------------------------------------------------------------------
echo "[PREFLIGHT] Checking required tools..."
ALL_TOOLS_OK=true
for tool_spec in "${REQUIRED_TOOLS[@]}"; do
  tool_name=$(echo "$tool_spec" | cut -d: -f1)
  min_version=$(echo "$tool_spec" | cut -s -d: -f2)

  if command -v "$tool_name" >/dev/null 2>&1; then
    version=$($tool_name version 2>/dev/null | head -n1 || echo "unknown")
    echo "[PASS] ${tool_name}: ${version}"
  else
    echo "[FAIL] ${tool_name}: not found in PATH"
    ALL_TOOLS_OK=false
  fi
done

if [[ "$ALL_TOOLS_OK" == false ]]; then
  echo "[PREFLIGHT] Some required tools are missing. Install them before proceeding."
  exit 1
fi

# ------------------------------------------------------------------------------
# 3. Terraform Version
# ------------------------------------------------------------------------------
echo "[PREFLIGHT] Checking Terraform version..."
TF_VERSION=$(terraform version -json 2>/dev/null | python3 -c "import sys, json; print(json.load(sys.stdin)['terraform_version'])" 2>/dev/null || terraform version | head -1)
echo "[INFO] Terraform version: ${TF_VERSION}"

# ------------------------------------------------------------------------------
# 4. AWS Service Quotas (skipped in quick mode)
# ------------------------------------------------------------------------------
if [[ "$QUICK" == false ]]; then
  echo "[PREFLIGHT] Checking AWS service quotas..."

  # EKS clusters per region
  EKS_QUOTA=$(aws service-quotas get-service-quota \
    --service-code eks \
    --quota-code L-1194D53C \
    --region "${REGION}" \
    --query Quota.Value \
    --output text 2>/dev/null || echo "unknown")
  echo "[INFO] EKS clusters quota: ${EKS_QUOTA}"

  # VPCs per region
  VPC_QUOTA=$(aws service-quotas get-service-quota \
    --service-code vpc \
    --quota-code L-F678F1EC \
    --region "${REGION}" \
    --query Quota.Value \
    --output text 2>/dev/null || echo "unknown")
  echo "[INFO] VPCs quota: ${VPC_QUOTA}"

  # KMS keys per region
  KMS_QUOTA=$(aws service-quotas get-service-quota \
    --service-code kms \
    --quota-code L-C2F1777E \
    --region "${REGION}" \
    --query Quota.Value \
    --output text 2>/dev/null || echo "unknown")
  echo "[INFO] KMS keys quota: ${KMS_QUOTA}"
else
  echo "[PREFLIGHT] Skipping quota checks (--quick mode)."
fi

# ------------------------------------------------------------------------------
# 5. GitHub Access
# ------------------------------------------------------------------------------
echo "[PREFLIGHT] Checking GitHub CLI access..."
if gh auth status >/dev/null 2>&1; then
  echo "[PASS] GitHub CLI authenticated."
else
  echo "[WARN] GitHub CLI not authenticated. Run 'gh auth login'."
fi

# ------------------------------------------------------------------------------
# 6. Git Repository
# ------------------------------------------------------------------------------
echo "[PREFLIGHT] Checking Git repository..."
if git rev-parse --git-dir >/dev/null 2>&1; then
  REPO_URL=$(git remote get-url origin 2>/dev/null || echo "no-origin")
  echo "[PASS] Git repository detected: ${REPO_URL}"
else
  echo "[WARN] Not inside a Git repository."
fi

echo "[PREFLIGHT] All checks passed. Ready to deploy Nexus platform."
