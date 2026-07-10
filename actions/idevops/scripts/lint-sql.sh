#!/usr/bin/env bash
# [iDevOps] Lint script for SQL using SQLFluff and sqlfmt
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

has_sql() { find "$TARGET" -maxdepth 3 -name "*.sql" -type f 2>/dev/null | head -1 | grep -q .; }

if ! has_sql; then
  warn "No SQL files found. Skipping."
  exit 0
fi

# --- SQLFluff ---
log "--- SQLFluff ---"
if ! command -v sqlfluff &>/dev/null; then
  log "Installing SQLFluff..."
  if command -v pip &>/dev/null; then pip install --user sqlfluff 2>/dev/null || true; fi
fi
if command -v sqlfluff &>/dev/null; then
  sqlfluff lint "$TARGET" --format json 2>&1 | tee /tmp/sqlfluff-results.json
  check_exit ${PIPESTATUS[0]} "SQLFluff"
else
  warn "SQLFluff installation failed. Skipping."
fi

# --- sqlfmt ---
log "--- sqlfmt ---"
if ! command -v sqlfmt &>/dev/null; then
  log "Installing sqlfmt..."
  if command -v pip &>/dev/null; then pip install --user shandy-sqlfmt 2>/dev/null || true; fi
fi
if command -v sqlfmt &>/dev/null; then
  find "$TARGET" -maxdepth 3 -name "*.sql" -type f -exec sqlfmt --check {} + 2>&1
  check_exit $? "sqlfmt"
else
  warn "sqlfmt installation failed. Skipping."
fi

log "=== SQL lint complete ==="
exit $EXIT_CODE
