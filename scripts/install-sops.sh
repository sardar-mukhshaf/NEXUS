#!/usr/bin/env bash
# =============================================================================
# NEXUS PLATFORM — SOPS Installer
# Installs Mozilla SOPS with AWS KMS support.
# =============================================================================
set -euo pipefail

SOPS_VERSION="3.8.1"
INSTALL_DIR="/usr/local/bin"

show_help() {
  cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Install Mozilla SOPS ${SOPS_VERSION}.

Options:
  -h, --help       Show this help message
  -d, --dir DIR    Install directory (default: /usr/local/bin)
EOF
}

while [[ $# -gt 0 ]]; do
  case $1 in
    -h|--help) show_help; exit 0 ;;
    -d|--dir) INSTALL_DIR="$2"; shift 2 ;;
    *) echo "Unknown option: $1"; show_help; exit 1 ;;
  esac
done

echo "[SOPS] Checking for existing SOPS installation..."
if command -v sops >/dev/null 2>&1; then
  CURRENT_VERSION=$(sops --version 2>/dev/null | awk '{print $2}' || echo "unknown")
  echo "[SOPS] Found existing version: ${CURRENT_VERSION}"
  if [[ "$CURRENT_VERSION" == "$SOPS_VERSION" ]]; then
    echo "[SOPS] Already at desired version. Skipping."
    exit 0
  fi
fi

OS=$(uname -s | tr '[:upper:]' '[:lower:]')
ARCH=$(uname -m)
case "$ARCH" in
  x86_64) ARCH="amd64" ;;
  aarch64|arm64) ARCH="arm64" ;;
  *) echo "[ERROR] Unsupported architecture: $ARCH"; exit 1 ;;
esac

DOWNLOAD_URL="https://github.com/getsops/sops/releases/download/v${SOPS_VERSION}/sops-v${SOPS_VERSION}.${OS}.${ARCH}"
TMP_FILE="/tmp/sops-${SOPS_VERSION}"

echo "[SOPS] Downloading from ${DOWNLOAD_URL}..."
curl -fsSL -o "${TMP_FILE}" "${DOWNLOAD_URL}"
chmod +x "${TMP_FILE}"

echo "[SOPS] Installing to ${INSTALL_DIR}/sops..."
mkdir -p "${INSTALL_DIR}"
mv "${TMP_FILE}" "${INSTALL_DIR}/sops"

echo "[SOPS] Verifying installation..."
sops --version

echo "[SOPS] Installation complete."
