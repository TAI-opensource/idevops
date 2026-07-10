#!/usr/bin/env bash
# [iDevOps] Lint script for Ruby using RuboCop and StandardRB
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

has_ruby() { find "$TARGET" -maxdepth 3 -name "*.rb" -type f 2>/dev/null | head -1 | grep -q .; }

if ! has_ruby; then
  warn "No Ruby files found. Skipping."
  exit 0
fi

# --- RuboCop ---
log "--- RuboCop ---"
if ! command -v rubocop &>/dev/null; then
  log "Installing RuboCop..."
  if command -v gem &>/dev/null; then gem install rubocop 2>/dev/null || true; fi
fi
if command -v rubocop &>/dev/null; then
  rubocop --format json --out /tmp/rubocop-results.json "$TARGET" 2>&1
  rubocop "$TARGET" 2>&1
  check_exit $? "RuboCop"
else
  warn "RuboCop installation failed. Skipping."
fi

# --- StandardRB ---
log "--- StandardRB ---"
if ! command -v standardrb &>/dev/null; then
  log "Installing StandardRB..."
  if command -v gem &>/dev/null; then gem install standard 2>/dev/null || true; fi
fi
if command -v standardrb &>/dev/null; then
  standardrb "$TARGET" 2>&1
  check_exit $? "StandardRB"
elif command -v standard &>/dev/null; then
  standard "$TARGET" 2>&1
  check_exit $? "StandardRB"
else
  warn "StandardRB installation failed. Skipping."
fi

log "=== Ruby lint complete ==="
exit $EXIT_CODE
