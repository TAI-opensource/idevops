#!/usr/bin/env bash
# [iDevOps] Lint script for Helm using helm lint and kubeconform
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

has_helm() { find "$TARGET" -maxdepth 3 -name "Chart.yaml" -type f 2>/dev/null | head -1 | grep -q .; }

if ! has_helm; then
  warn "No Helm charts found. Skipping."
  exit 0
fi

# --- helm lint ---
log "--- helm lint ---"
if command -v helm &>/dev/null; then
  find "$TARGET" -maxdepth 3 -name "Chart.yaml" -type f | while read -r chart; do
    CHART_DIR=$(dirname "$chart")
    log "Linting $CHART_DIR"
    helm lint "$CHART_DIR" 2>&1
    check_exit $? "helm lint"
  done
else
  warn "helm not found. Skipping."
fi

# --- kubeconform ---
log "--- kubeconform ---"
if command -v kubeconform &>/dev/null; then
  find "$TARGET" -maxdepth 3 -name "Chart.yaml" -type f | while read -r chart; do
    CHART_DIR=$(dirname "$chart")
    log "Validating $CHART_DIR with kubeconform"
    helm template "$CHART_DIR" 2>/dev/null | kubeconform -strict 2>&1
    check_exit $? "kubeconform"
  done
elif command -v helm &>/dev/null; then
  log "kubeconform not found. Installing..."
  KUBECONFORM_VERSION="0.6.4"
  curl -sL -o /tmp/kubeconform.tar.gz "https://github.com/yannh/kubeconform/releases/latest/download/kubeconform-linux-amd64.tar.gz" 2>/dev/null || true
  tar -xzf /tmp/kubeconform.tar.gz -C /tmp kubeconform 2>/dev/null || true
  sudo mv /tmp/kubeconform /usr/local/bin/kubeconform 2>/dev/null || true
  if command -v kubeconform &>/dev/null; then
    find "$TARGET" -maxdepth 3 -name "Chart.yaml" -type f | while read -r chart; do
      CHART_DIR=$(dirname "$chart")
      helm template "$CHART_DIR" 2>/dev/null | kubeconform -strict 2>&1
      check_exit $? "kubeconform"
    done
  fi
else
  warn "kubeconform and helm not found. Skipping."
fi

log "=== Helm lint complete ==="
exit $EXIT_CODE
