#!/usr/bin/env bash
# [iDevOps] Lint script for Docker using Hadolint and Dockle
set -euo pipefail

FAIL_ON="${FAIL_ON:-warning}"
TARGET="${1:-.}"
EXIT_CODE=0

log() { echo "[iDevOps] $*"; }
warn() { log "WARN: $*"; }
ok() { log "OK: $*"; }

check_exit() {
  local code=$1 tool=$2
  case "$FAIL_ON" in
    error)   [[ $code -gt 1 ]] && EXIT_CODE=1 ;;
    warning) [[ $code -gt 0 ]] && EXIT_CODE=1 ;;
    info)    [[ $code -ne 0 ]] && EXIT_CODE=1 ;;
    none)    ;;
  esac
  if [[ $code -eq 0 ]]; then ok "$tool passed"; else warn "$tool found issues (exit $code)"; fi
}

has_docker() { find "$TARGET" -maxdepth 3 \( -name "Dockerfile*" -o -name "*.dockerfile" \) -type f 2>/dev/null | head -1 | grep -q .; }

if ! has_docker; then
  warn "No Dockerfile found. Skipping."
  exit 0
fi

# --- Hadolint ---
log "--- Hadolint ---"
if ! command -v hadolint &>/dev/null; then
  log "Installing Hadolint..."
  HADOLINT_VERSION="2.12.0"
  curl -sL -o /tmp/hadolint "https://github.com/hadolint/hadolint/releases/download/v${HADOLINT_VERSION}/hadolint-Linux-x86_64" 2>/dev/null || true
  chmod +x /tmp/hadolint 2>/dev/null || true
  sudo mv /tmp/hadolint /usr/local/bin/hadolint 2>/dev/null || true
fi
if command -v hadolint &>/dev/null; then
  find "$TARGET" -maxdepth 3 \( -name "Dockerfile*" -o -name "*.dockerfile" \) -type f -exec hadolint --format json {} + 2>&1 | tee /tmp/hadolint-results.json
  check_exit ${PIPESTATUS[0]} "Hadolint"
else
  warn "Hadolint installation failed. Skipping."
fi

# --- Dockle ---
log "--- Dockle ---"
if ! command -v dockle &>/dev/null; then
  log "Installing Dockle..."
  DOCKLE_VERSION="0.4.9"
  curl -sL -o /tmp/dockle.tar.gz "https://github.com/goodwithtech/dockle/releases/download/v${DOCKLE_VERSION}/dockle_${DOCKLE_VERSION}_Linux-64bit.tar.gz" 2>/dev/null || true
  tar -xzf /tmp/dockle.tar.gz -C /tmp dockle 2>/dev/null || true
  sudo mv /tmp/dockle /usr/local/bin/dockle 2>/dev/null || true
fi
if command -v dockle &>/dev/null; then
  IMAGE_NAME=$(basename "$TARGET" | tr '[:upper:]' '[:lower:]' | tr -cd 'a-z0-9._-')
  dockle --format json "$IMAGE_NAME" 2>&1 | tee /tmp/dockle-results.json
  check_exit ${PIPESTATUS[0]} "Dockle"
else
  warn "Dockle installation failed. Skipping."
fi

log "=== Docker lint complete ==="
exit $EXIT_CODE
