#!/usr/bin/env bash
# [iDevOps] Lint script for Dart using dart analyze and dart format
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

has_dart() { find "$TARGET" -maxdepth 3 -name "*.dart" -type f 2>/dev/null | head -1 | grep -q .; }

if ! has_dart; then
  warn "No Dart files found. Skipping."
  exit 0
fi

# --- dart analyze ---
log "--- dart analyze ---"
if command -v dart &>/dev/null; then
  dart analyze "$TARGET" 2>&1
  check_exit $? "dart analyze"
else
  warn "dart not found. Skipping."
fi

# --- dart format ---
log "--- dart format ---"
if command -v dart &>/dev/null; then
  if dart format --set-exit-if-changed "$TARGET" 2>&1; then
    check_exit 0 "dart format"
  else
    check_exit $? "dart format"
  fi
else
  warn "dart not found. Skipping."
fi

log "=== Dart lint complete ==="
exit $EXIT_CODE
