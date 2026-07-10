#!/usr/bin/env bash
# [iDevOps] Lint script for Ansible using ansible-lint
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

has_ansible() {
  find "$TARGET" -maxdepth 3 \( -name "*.yml" -o -name "*.yaml" \) -type f 2>/dev/null | xargs grep -l "ansible" 2>/dev/null | head -1 | grep -q .
}

if ! has_ansible; then
  warn "No Ansible files found. Skipping."
  exit 0
fi

# --- ansible-lint ---
log "--- ansible-lint ---"
if ! command -v ansible-lint &>/dev/null; then
  log "Installing ansible-lint..."
  if command -v pip &>/dev/null; then pip install --user ansible-lint 2>/dev/null || true; fi
fi
if command -v ansible-lint &>/dev/null; then
  ansible-lint --format json "$TARGET" 2>&1 | tee /tmp/ansible-lint-results.json
  check_exit ${PIPESTATUS[0]} "ansible-lint"
else
  warn "ansible-lint installation failed. Skipping."
fi

log "=== Ansible lint complete ==="
exit $EXIT_CODE
