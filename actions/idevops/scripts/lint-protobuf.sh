#!/usr/bin/env bash
# [iDevOps] Lint script for Protobuf using buf lint and buf format
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

has_proto() { find "$TARGET" -maxdepth 3 -name "*.proto" -type f 2>/dev/null | head -1 | grep -q .; }

if ! has_proto; then
  warn "No Protobuf files found. Skipping."
  exit 0
fi

# --- buf ---
log "--- buf lint ---"
if ! command -v buf &>/dev/null; then
  log "Installing buf..."
  if command -v brew &>/dev/null; then brew install bufbuild/buf/buf 2>/dev/null || true;
  elif command -v go &>/dev/null; then go install github.com/bufbuild/buf/cmd/buf@latest 2>/dev/null || true;
  elif command -v npm &>/dev/null; then npm install -g @bufbuild/buf 2>/dev/null || true; fi
fi
if command -v buf &>/dev/null; then
  buf lint "$TARGET" 2>&1
  check_exit $? "buf lint"
else
  warn "buf installation failed. Skipping."
fi

# --- buf format ---
log "--- buf format ---"
if command -v buf &>/dev/null; then
  if buf format --diff "$TARGET" 2>&1; then
    check_exit 0 "buf format"
  else
    check_exit $? "buf format"
  fi
else
  warn "buf not found. Skipping."
fi

log "=== Protobuf lint complete ==="
exit $EXIT_CODE
