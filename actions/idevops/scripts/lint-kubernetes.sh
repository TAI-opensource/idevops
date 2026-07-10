#!/usr/bin/env bash
# [iDevOps] Lint script for Kubernetes using kubeconform, kube-linter, and polaris
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

has_k8s() { find "$TARGET" -maxdepth 3 \( -name "*.yaml" -o -name "*.yml" \) -type f -exec grep -l "apiVersion" {} + 2>/dev/null | head -1 | grep -q .; }

if ! has_k8s; then
  warn "No Kubernetes manifests found. Skipping."
  exit 0
fi

# --- kubeconform ---
log "--- kubeconform ---"
if ! command -v kubeconform &>/dev/null; then
  log "Installing kubeconform..."
  KUBECONFORM_VERSION="0.6.4"
  curl -sL -o /tmp/kubeconform.tar.gz "https://github.com/yannh/kubeconform/releases/latest/download/kubeconform-linux-amd64.tar.gz" 2>/dev/null || true
  tar -xzf /tmp/kubeconform.tar.gz -C /tmp kubeconform 2>/dev/null || true
  sudo mv /tmp/kubeconform /usr/local/bin/kubeconform 2>/dev/null || true
fi
if command -v kubeconform &>/dev/null; then
  find "$TARGET" -maxdepth 3 \( -name "*.yaml" -o -name "*.yml" \) -type f -exec grep -l "apiVersion" {} + 2>/dev/null | xargs kubeconform -output json 2>&1 | tee /tmp/kubeconform-results.json
  check_exit ${PIPESTATUS[0]} "kubeconform"
else
  warn "kubeconform installation failed. Skipping."
fi

# --- kube-linter ---
log "--- kube-linter ---"
if ! command -v kube-linter &>/dev/null; then
  log "Installing kube-linter..."
  if command -v brew &>/dev/null; then brew install kube-linter 2>/dev/null || true;
  elif command -v go &>/dev/null; then go install github.com/stackrox/kube-linter@latest 2>/dev/null || true; fi
fi
if command -v kube-linter &>/dev/null; then
  kube-linter lint "$TARGET" 2>&1
  check_exit $? "kube-linter"
else
  warn "kube-linter installation failed. Skipping."
fi

# --- polaris ---
log "--- polaris ---"
if ! command -v polaris &>/dev/null; then
  log "Installing polaris..."
  POLARIS_VERSION="9.3.7"
  curl -sL -o /tmp/polaris.tar.gz "https://github.com/FairwindsOps/polaris/releases/download/${POLARIS_VERSION}/polaris_linux_amd64.tar.gz" 2>/dev/null || true
  tar -xzf /tmp/polaris.tar.gz -C /tmp polaris 2>/dev/null || true
  sudo mv /tmp/polaris /usr/local/bin/polaris 2>/dev/null || true
fi
if command -v polaris &>/dev/null; then
  polaris audit --format=json "$TARGET" 2>&1 | tee /tmp/polaris-results.json
  check_exit ${PIPESTATUS[0]} "polaris"
else
  warn "polaris installation failed. Skipping."
fi

log "=== Kubernetes lint complete ==="
exit $EXIT_CODE
