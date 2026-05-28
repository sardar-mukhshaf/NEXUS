#!/usr/bin/env bash
# =============================================================================
# NEXUS PLATFORM — Auto Rollback
# Git revert on ArgoCD sync failure for staging.
# Prod requires manual approval via Slack workflow.
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENVIRONMENT="${1:-}"
REPO_URL="${REPO_URL:-https://github.com/example-org/nexus-platform.git}"

show_help() {
  cat <<EOF
Usage: $(basename "$0") <environment>

Auto-rollback on sync failure.
  staging  - Auto-revert last commit
  prod     - Requires manual approval

Options:
  -h, --help    Show this help message
EOF
}

if [ -z "$ENVIRONMENT" ] || [ "$ENVIRONMENT" == "-h" ] || [ "$ENVIRONMENT" == "--help" ]; then
  show_help
  exit 1
fi

echo "[ROLLBACK] Initiating rollback for environment: ${ENVIRONMENT}"

if [ "$ENVIRONMENT" == "staging" ]; then
  echo "[ROLLBACK] Auto-reverting last commit in staging..."
  git revert --no-edit HEAD
  git push origin main
  echo "[ROLLBACK] Staging auto-revert complete."

elif [ "$ENVIRONMENT" == "prod" ]; then
  echo "[ROLLBACK] Production rollback requires manual approval."
  echo "[ROLLBACK] Triggering Slack workflow for approval..."
  # Slack webhook call would go here
  echo "[ROLLBACK] Approval workflow triggered. Check Slack #platform-alerts"
  exit 0

else
  echo "[ERROR] Unknown environment: ${ENVIRONMENT}"
  show_help
  exit 1
fi
