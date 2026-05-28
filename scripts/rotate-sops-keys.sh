#!/usr/bin/env bash
# =============================================================================
# NEXUS PLATFORM — Rotate SOPS Keys
# Re-encrypts all secrets with new KMS key.
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOPS_DIR="${SCRIPT_DIR}/../gitops/sops/secrets"

echo "[SOPS] Starting SOPS key rotation..."

# Find all encrypted files
find "$SOPS_DIR" -name "*.enc.yaml" -o -name "*.enc.json" | while read -r file; do
  echo "[SOPS] Rotating: $file"
  sops --rotate --in-place "$file"
done

echo "[SOPS] Key rotation complete. Commit and push the updated files."
