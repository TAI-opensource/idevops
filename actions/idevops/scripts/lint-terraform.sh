#!/usr/bin/env bash
# [iDevOps] Lint script for Terraform using tflint, tfsec, checkov, and terraform fmt
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

has_tf() { find "$TARGET" -maxdepth 3 -name "*.tf" -type f 2>/dev/null | head -1 | grep -q .; }

if ! has_tf; then
  warn "No Terraform files found. Skipping."
  exit 0
fi

# --- tflint ---
log "--- tflint ---"
if ! command -v tflint &>/dev/null; then
  log "Installing tflint..."
  curl -s https://raw.githubusercontent.com/terraform-linters/tflint/master/install_linux.sh | bash 2>/dev/null || true
fi
if command -v tflint &>/dev/null; then
  tflint --format json "$TARGET" 2>&1 | tee /tmp/tflint-results.json
  check_exit ${PIPESTATUS[0]} "tflint"
else
  warn "tflint installation failed. Skipping."
fi

# --- tfsec ---
log "--- tfsec ---"
if ! command -v tfsec &>/dev/null; then
  log "Installing tfsec..."
  if command -v brew &>/dev/null; then brew install tfsec 2>/dev/null || true;
  elif command -v go &>/dev/null; then go install github.com/aquasecurity/tfsec/cmd/tfsec@latest 2>/dev/null || true; fi
fi
if command -v tfsec &>/dev/null; then
  tfsec --format json "$TARGET" 2>&1 | tee /tmp/tfsec-results.json
  check_exit ${PIPESTATUS[0]} "tfsec"
else
  warn "tfsec installation failed. Skipping."
fi

# --- checkov ---
log "--- checkov ---"
if ! command -v checkov &>/dev/null; then
  log "Installing checkov..."
  if command -v pip &>/dev/null; then pip install --user checkov 2>/dev/null || true; fi
fi
if command -v checkov &>/dev/null; then
  checkov -d "$TARGET" --output json 2>&1 | tee /tmp/checkov-results.json
  check_exit ${PIPESTATUS[0]} "checkov"
else
  warn "checkov installation failed. Skipping."
fi

# --- terraform fmt ---
log "--- terraform fmt ---"
if command -v terraform &>/dev/null; then
  if terraform fmt -check -diff "$TARGET" 2>&1; then
    check_exit 0 "terraform fmt"
  else
    check_exit $? "terraform fmt"
  fi
else
  warn "terraform not found. Skipping."
fi

log "=== Terraform lint complete ==="
exit $EXIT_CODE
