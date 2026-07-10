#!/usr/bin/env bash
# [iDevOps] Lint script for YAML using yamllint and Prettier
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

has_yaml() { find "$TARGET" -maxdepth 3 \( -name "*.yml" -o -name "*.yaml" \) -type f 2>/dev/null | head -1 | grep -q .; }

if ! has_yaml; then
  warn "No YAML files found. Skipping."
  exit 0
fi

# --- yamllint ---
log "--- yamllint ---"
if ! command -v yamllint &>/dev/null; then
  log "Installing yamllint..."
  if command -v pip &>/dev/null; then pip install --user yamllint 2>/dev/null || true; fi
fi
if command -v yamllint &>/dev/null; then
  yamllint -f parsable -s "$TARGET" 2>&1
  check_exit $? "yamllint"
else
  warn "yamllint installation failed. Skipping."
fi

# --- Prettier (YAML) ---
log "--- Prettier (YAML) ---"
if command -v npx &>/dev/null || command -v prettier &>/dev/null; then
  PRETTIER_CMD="npx prettier"
  if command -v prettier &>/dev/null; then PRETTIER_CMD="prettier"; fi
  if [[ -f ".prettierrc" ]] || [[ -f ".prettierrc.json" ]]; then
    find "$TARGET" -maxdepth 3 \( -name "*.yml" -o -name "*.yaml" \) -type f -exec $PRETTIER_CMD --check {} + 2>&1
    check_exit $? "Prettier"
  else
    warn "No .prettierrc found. Skipping Prettier for YAML."
  fi
else
  warn "Prettier not found. Skipping."
fi

log "=== YAML lint complete ==="
exit $EXIT_CODE
