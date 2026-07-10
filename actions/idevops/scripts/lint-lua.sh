#!/usr/bin/env bash
# [iDevOps] Lint script for Lua using luacheck and StyLua
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

has_lua() { find "$TARGET" -maxdepth 3 -name "*.lua" -type f 2>/dev/null | head -1 | grep -q .; }

if ! has_lua; then
  warn "No Lua files found. Skipping."
  exit 0
fi

# --- luacheck ---
log "--- luacheck ---"
if ! command -v luacheck &>/dev/null; then
  log "Installing luacheck..."
  if command -v luarocks &>/dev/null; then luarocks install luacheck 2>/dev/null || true; fi
fi
if command -v luacheck &>/dev/null; then
  luacheck "$TARGET" --codes --formatter json 2>&1 | tee /tmp/luacheck-results.json
  check_exit ${PIPESTATUS[0]} "luacheck"
else
  warn "luacheck installation failed. Skipping."
fi

# --- StyLua ---
log "--- StyLua ---"
if ! command -v stylua &>/dev/null; then
  log "Installing StyLua..."
  if command -v cargo &>/dev/null; then cargo install stylua 2>/dev/null || true;
  elif command -v brew &>/dev/null; then brew install stylua 2>/dev/null || true; fi
fi
if command -v stylua &>/dev/null; then
  stylua --check "$TARGET" 2>&1
  check_exit $? "StyLua"
else
  warn "StyLua installation failed. Skipping."
fi

log "=== Lua lint complete ==="
exit $EXIT_CODE
