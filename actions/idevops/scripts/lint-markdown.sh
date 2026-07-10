#!/usr/bin/env bash
# [iDevOps] Lint script for Markdown using markdownlint-cli2, remark-lint, and Prettier
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

has_md() { find "$TARGET" -maxdepth 3 -name "*.md" -type f 2>/dev/null | head -1 | grep -q .; }

if ! has_md; then
  warn "No Markdown files found. Skipping."
  exit 0
fi

# --- markdownlint-cli2 ---
log "--- markdownlint-cli2 ---"
if ! command -v markdownlint-cli2 &>/dev/null && ! command -v markdownlint &>/dev/null; then
  log "Installing markdownlint-cli2..."
  if command -v npm &>/dev/null; then npm install -g markdownlint-cli2 2>/dev/null || true; fi
fi
if command -v markdownlint-cli2 &>/dev/null; then
  markdownlint-cli2 "$TARGET/**/*.md" 2>&1
  check_exit $? "markdownlint-cli2"
elif command -v markdownlint &>/dev/null; then
  markdownlint "$TARGET/**/*.md" 2>&1
  check_exit $? "markdownlint"
else
  warn "markdownlint-cli2 installation failed. Skipping."
fi

# --- remark-lint ---
log "--- remark-lint ---"
if command -v npx &>/dev/null; then
  if [[ -f ".remarkrc" ]] || [[ -f ".remarkrc.json" ]] || [[ -f ".remarkrc.js" ]]; then
    npx remark "$TARGET/**/*.md" 2>&1
    check_exit $? "remark-lint"
  else
    warn "No .remarkrc found. Skipping remark-lint."
  fi
else
  warn "npx not found. Skipping remark-lint."
fi

# --- Prettier (Markdown) ---
log "--- Prettier (Markdown) ---"
if command -v npx &>/dev/null || command -v prettier &>/dev/null; then
  PRETTIER_CMD="npx prettier"
  if command -v prettier &>/dev/null; then PRETTIER_CMD="prettier"; fi
  if [[ -f ".prettierrc" ]] || [[ -f ".prettierrc.json" ]]; then
    find "$TARGET" -maxdepth 3 -name "*.md" -type f -exec $PRETTIER_CMD --check {} + 2>&1
    check_exit $? "Prettier"
  else
    warn "No .prettierrc found. Skipping Prettier for Markdown."
  fi
else
  warn "Prettier not found. Skipping."
fi

log "=== Markdown lint complete ==="
exit $EXIT_CODE
