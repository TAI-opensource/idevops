#!/usr/bin/env bash
# [iDevOps] Lint script for Haskell using HLint, ormolu, and fourmolu
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

has_hs() { find "$TARGET" -maxdepth 3 -name "*.hs" -type f 2>/dev/null | head -1 | grep -q .; }

if ! has_hs; then
  warn "No Haskell files found. Skipping."
  exit 0
fi

# --- HLint ---
log "--- HLint ---"
if ! command -v hlint &>/dev/null; then
  log "Installing HLint..."
  if command -v cabal &>/dev/null; then cabal install hlint 2>/dev/null || true; fi
  if command -v stack &>/dev/null; then stack install hlint 2>/dev/null || true; fi
fi
if command -v hlint &>/dev/null; then
  hlint "$TARGET" --json 2>&1 | tee /tmp/hlint-results.json
  check_exit ${PIPESTATUS[0]} "HLint"
else
  warn "HLint installation failed. Skipping."
fi

# --- ormolu ---
log "--- ormolu ---"
if ! command -v ormolu &>/dev/null; then
  log "Installing ormolu..."
  if command -v cabal &>/dev/null; then cabal install ormolu 2>/dev/null || true; fi
  if command -v stack &>/dev/null; then stack install ormolu 2>/dev/null || true; fi
fi
if command -v ormolu &>/dev/null; then
  find "$TARGET" -name "*.hs" -exec ormolu --mode check {} + 2>&1
  check_exit $? "ormolu"
else
  warn "ormolu installation failed. Skipping."
fi

# --- fourmolu ---
log "--- fourmolu ---"
if ! command -v fourmolu &>/dev/null; then
  log "Installing fourmolu..."
  if command -v cabal &>/dev/null; then cabal install fourmolu 2>/dev/null || true; fi
  if command -v stack &>/dev/null; then stack install fourmolu 2>/dev/null || true; fi
fi
if command -v fourmolu &>/dev/null; then
  find "$TARGET" -name "*.hs" -exec fourmolu --mode check {} + 2>&1
  check_exit $? "fourmolu"
else
  warn "fourmolu installation failed. Skipping."
fi

log "=== Haskell lint complete ==="
exit $EXIT_CODE
