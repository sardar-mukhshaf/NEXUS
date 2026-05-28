#!/usr/bin/env bash
# =============================================================================
# NEXUS PLATFORM — Verify Deployment
# Pre-deployment: image signature, scan results, SBOM existence.
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IMAGE="${1:-}"

show_help() {
  cat <<EOF
Usage: $(basename "$0") <image-uri>

Verify image signature, scan results, and SBOM before deployment.

Options:
  -h, --help    Show this help message
EOF
}

if [ -z "$IMAGE" ] || [ "$IMAGE" == "-h" ] || [ "$IMAGE" == "--help" ]; then
  show_help
  exit 1
fi

echo "[VERIFY] Verifying deployment for image: ${IMAGE}"

# 1. Verify Cosign signature
echo "[VERIFY] Checking image signature..."
if cosign verify --key awskms:///alias/nexus-cosign "$IMAGE"; then
  echo "[VERIFY] Signature valid."
else
  echo "[FAIL] Image signature verification failed."
  exit 1
fi

# 2. Check Trivy scan results
echo "[VERIFY] Checking Trivy scan results..."
TRIVY_REPORT=$(trivy image --format json --severity HIGH,CRITICAL "$IMAGE" 2>/dev/null)
CRITICAL_COUNT=$(echo "$TRIVY_REPORT" | jq '[.Results[].Vulnerabilities? // [] | .[] | select(.Severity == "CRITICAL")] | length')
HIGH_COUNT=$(echo "$TRIVY_REPORT" | jq '[.Results[].Vulnerabilities? // [] | .[] | select(.Severity == "HIGH")] | length')

if [ "$CRITICAL_COUNT" -gt 0 ]; then
  echo "[FAIL] ${CRITICAL_COUNT} critical CVE(s) found."
  exit 1
fi

if [ "$HIGH_COUNT" -gt 5 ]; then
  echo "[FAIL] ${HIGH_COUNT} high CVE(s) found (max allowed: 5)."
  exit 1
fi

echo "[VERIFY] CVE check passed: ${CRITICAL_COUNT} critical, ${HIGH_COUNT} high."

# 3. Verify SBOM exists
echo "[VERIFY] Checking SBOM attachment..."
if cosign download sbom "$IMAGE" >/dev/null 2>&1; then
  echo "[VERIFY] SBOM attached and valid."
else
  echo "[FAIL] SBOM not found or invalid."
  exit 1
fi

echo "[VERIFY] All checks passed. Image is safe to deploy."
