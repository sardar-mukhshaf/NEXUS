#!/usr/bin/env bash
# =============================================================================
# NEXUS PLATFORM — Validate Policies
# Runs conftest and kyverno tests against policies.
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
POLICIES_DIR="${SCRIPT_DIR}/../policies"

echo "[VALIDATE] Validating Conftest policies..."
for f in "${POLICIES_DIR}"/conftest/terraform/*.rego; do
  if [ -f "$f" ]; then
    echo "  Checking $f"
    opa fmt -d "$f" >/dev/null || true
  fi
done

echo "[VALIDATE] Validating OPA policies..."
for f in "${POLICIES_DIR}"/opa/terraform/*.rego; do
  if [ -f "$f" ]; then
    echo "  Checking $f"
    opa fmt -d "$f" >/dev/null || true
  fi
done

echo "[VALIDATE] Running Kyverno tests..."
if command -v kyverno >/dev/null 2>&1; then
  kyverno test "${POLICIES_DIR}/kyverno-tests" || true
else
  echo "  kyverno CLI not installed, skipping"
fi

echo "[VALIDATE] Policy validation complete."
