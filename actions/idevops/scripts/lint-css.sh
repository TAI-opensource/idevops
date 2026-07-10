#!/usr/bin/env bash
# [iDevOps] Lint script for CSS using stylelint and Prettier
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

has_css() { find "$TARGET" -maxdepth 3 \( -name "*.css" -o -name "*.scss" -o -name "*.less" \) -type f 2>/dev/null | head -1 | grep -q .; }

if ! has_css; then
  warn "No CSS files found. Skipping."
  exit 0
fi

# --- stylelint ---
log "--- stylelint ---"
if ! command -v stylelint &>/dev/null; then
  log "Installing stylelint..."
  if command -v npm &>/dev/null; then npm install -g stylelint stylelint-config-standard 2>/dev/null || true; fi
fi
if command -v stylelint &>/dev/null || command -v npx &>/dev/null; then
  STYLELINT_CMD="stylelint"
  if ! command -v stylelint &>/dev/null; then STYLELINT_CMD="npx stylelint"; fi
  if [[ -f ".stylelintrc" ]] || [[ -f ".stylelintrc.json" ]] || [[ -f ".stylelintrc.js" ]] || [[ -f "stylelint.config.js" ]]; then
    $STYLELINT_CMD --formatter json "$TARGET/**/*.css" 2>&1 | tee /tmp/stylelint-results.json
    check_exit ${PIPESTATUS[0]} "stylelint"
  else
    warn "No stylelint config found. Skipping."
  fi
else
  warn "stylelint installation failed. Skipping."
fi

# --- Prettier (CSS) ---
log "--- Prettier (CSS) ---"
if command -v npx &>/dev/null || command -v prettier &>/dev/null; then
  PRETTIER_CMD="npx prettier"
  if command -v prettier &>/dev/null; then PRETTIER_CMD="prettier"; fi
  if [[ -f ".prettierrc" ]] || [[ -f ".prettierrc.json" ]]; then
    find "$TARGET" -maxdepth 3 \( -name "*.css" -o -name "*.scss" \) -type f -exec $PRETTIER_CMD --check {} + 2>&1
    check_exit $? "Prettier"
  else
    warn "No .prettierrc found. Skipping Prettier for CSS."
  fi
else
  warn "Prettier not found. Skipping."
fi

log "=== CSS lint complete ==="
exit $EXIT_CODE
