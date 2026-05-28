#!/usr/bin/env bash
# =============================================================================
# NEXUS PLATFORM — Generate SBOM
# Syft + CycloneDX, signs SBOM with cosign.
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IMAGE="${1:-}"
OUTPUT_DIR="${2:-./sboms}"

show_help() {
  cat <<EOF
Usage: $(basename "$0") <image-uri> [output-dir]

Generate and sign SBOM for the given image.

Options:
  -h, --help    Show this help message
EOF
}

if [ -z "$IMAGE" ] || [ "$IMAGE" == "-h" ] || [ "$IMAGE" == "--help" ]; then
  show_help
  exit 1
fi

mkdir -p "${OUTPUT_DIR}"
SBOM_FILE="${OUTPUT_DIR}/sbom-$(date +%Y%m%d-%H%M%S).cyclonedx.json"

echo "[SBOM] Generating CycloneDX SBOM for ${IMAGE}..."
syft "$IMAGE" -o cyclonedx-json="${SBOM_FILE}"

echo "[SBOM] SBOM saved to ${SBOM_FILE}"

# Sign SBOM with cosign
echo "[SBOM] Signing SBOM with Cosign KMS..."
cosign sign-blob --key awskms:///alias/nexus-cosign "${SBOM_FILE}" --output-signature "${SBOM_FILE}.sig"

echo "[SBOM] SBOM signature saved to ${SBOM_FILE}.sig"

# Verify signature
echo "[SBOM] Verifying SBOM signature..."
cosign verify-blob --key awskms:///alias/nexus-cosign --signature "${SBOM_FILE}.sig" "${SBOM_FILE}"

echo "[SBOM] SBOM generation and signing complete."
