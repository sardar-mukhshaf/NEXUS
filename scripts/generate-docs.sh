#!/usr/bin/env bash
# =============================================================================
# NEXUS PLATFORM — Documentation Generator
# Calls terraform-docs and Python parser for Mermaid diagrams.
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="${SCRIPT_DIR}/.."
TF_DIR="${PROJECT_ROOT}/terraform"
DOCS_DIR="${PROJECT_ROOT}/docs/architecture"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)

mkdir -p "${DOCS_DIR}"

echo "[DOCS] Generating Terraform module documentation..."

# Generate terraform-docs for each module
for module in "${TF_DIR}"/modules/*/; do
  if [ -d "$module" ]; then
    module_name=$(basename "$module")
    echo "  Processing module: ${module_name}"
    terraform-docs markdown table "$module" > "${DOCS_DIR}/${module_name}-docs.md" 2>/dev/null || \
      echo "    terraform-docs not available, skipping ${module_name}"
  fi
done

# Generate Mermaid diagrams via Python
echo "[DOCS] Generating Mermaid diagrams..."
python3 "${SCRIPT_DIR}/generate-mermaid.py" \
  --tf-dir "${TF_DIR}" \
  --output-dir "${DOCS_DIR}" \
  --timestamp "${TIMESTAMP}"

echo "[DOCS] Documentation generated in ${DOCS_DIR}"
