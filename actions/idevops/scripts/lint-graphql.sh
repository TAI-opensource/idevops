#!/usr/bin/env bash
# [iDevOps] Lint script for GraphQL using graphql-eslint and Prettier
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

has_gql() { find "$TARGET" -maxdepth 3 -name "*.graphql" -type f 2>/dev/null | head -1 | grep -q .; }
has_gql_in_js() { find "$TARGET" -maxdepth 3 \( -name "*.js" -o -name "*.ts" \) -type f -exec grep -l "graphql" {} + 2>/dev/null | head -1 | grep -q .; }

if ! has_gql && ! has_gql_in_js; then
  warn "No GraphQL files found. Skipping."
  exit 0
fi

# --- graphql-eslint ---
log "--- graphql-eslint ---"
if command -v npx &>/dev/null; then
  if [[ -f ".eslintrc.js" ]] || [[ -f "eslint.config.js" ]]; then
    npx eslint --ext .graphql "$TARGET" 2>&1
    check_exit $? "graphql-eslint"
  else
    warn "No ESLint config found. Skipping graphql-eslint."
  fi
else
  warn "npx not found. Skipping graphql-eslint."
fi

# --- Prettier (GraphQL) ---
log "--- Prettier (GraphQL) ---"
if command -v npx &>/dev/null || command -v prettier &>/dev/null; then
  PRETTIER_CMD="npx prettier"
  if command -v prettier &>/dev/null; then PRETTIER_CMD="prettier"; fi
  if [[ -f ".prettierrc" ]] || [[ -f ".prettierrc.json" ]]; then
    find "$TARGET" -maxdepth 3 -name "*.graphql" -type f -exec $PRETTIER_CMD --check {} + 2>&1
    check_exit $? "Prettier"
  else
    warn "No .prettierrc found. Skipping Prettier for GraphQL."
  fi
else
  warn "Prettier not found. Skipping."
fi

log "=== GraphQL lint complete ==="
exit $EXIT_CODE
