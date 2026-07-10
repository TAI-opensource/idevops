#!/usr/bin/env bash
# [iDevOps] Lint script for HTML using htmlhint, Prettier, and djlint
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

has_html() { find "$TARGET" -maxdepth 3 \( -name "*.html" -o -name "*.htm" -o -name "*.hbs" -o -name "*.ejs" \) -type f 2>/dev/null | head -1 | grep -q .; }

if ! has_html; then
  warn "No HTML files found. Skipping."
  exit 0
fi

# --- htmlhint ---
log "--- htmlhint ---"
if ! command -v htmlhint &>/dev/null; then
  log "Installing htmlhint..."
  if command -v npm &>/dev/null; then npm install -g htmlhint 2>/dev/null || true; fi
fi
if command -v htmlhint &>/dev/null || command -v npx &>/dev/null; then
  HTMLHINT_CMD="htmlhint"
  if ! command -v htmlhint &>/dev/null; then HTMLHINT_CMD="npx htmlhint"; fi
  if [[ -f ".htmlhintrc" ]] || [[ -f ".htmlhintrc.json" ]]; then
    $HTMLHINT_CMD "$TARGET/**/*.html" 2>&1
    check_exit $? "htmlhint"
  else
    $HTMLHINT_CMD "$TARGET/**/*.html" 2>&1
    check_exit $? "htmlhint"
  fi
else
  warn "htmlhint installation failed. Skipping."
fi

# --- Prettier (HTML) ---
log "--- Prettier (HTML) ---"
if command -v npx &>/dev/null || command -v prettier &>/dev/null; then
  PRETTIER_CMD="npx prettier"
  if command -v prettier &>/dev/null; then PRETTIER_CMD="prettier"; fi
  if [[ -f ".prettierrc" ]] || [[ -f ".prettierrc.json" ]]; then
    find "$TARGET" -maxdepth 3 \( -name "*.html" -o -name "*.htm" \) -type f -exec $PRETTIER_CMD --check {} + 2>&1
    check_exit $? "Prettier"
  else
    warn "No .prettierrc found. Skipping Prettier for HTML."
  fi
else
  warn "Prettier not found. Skipping."
fi

# --- djlint ---
log "--- djlint ---"
if ! command -v djlint &>/dev/null; then
  log "Installing djlint..."
  if command -v pip &>/dev/null; then pip install --user djlint 2>/dev/null || true; fi
fi
if command -v djlint &>/dev/null; then
  djlint --check "$TARGET" 2>&1
  check_exit $? "djlint"
else
  warn "djlint installation failed. Skipping."
fi

log "=== HTML lint complete ==="
exit $EXIT_CODE
