#!/usr/bin/env bash
# [iDevOps] Lint script for Elixir using Credo, Dialyxir, and ElixirLS
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

has_elixir() { find "$TARGET" -maxdepth 3 -name "*.ex" -type f 2>/dev/null | head -1 | grep -q .; }

if ! has_elixir; then
  warn "No Elixir files found. Skipping."
  exit 0
fi

# --- Credo ---
log "--- Credo ---"
if ! command -v credo &>/dev/null; then
  log "Installing Credo..."
  if command -v mix &>/dev/null; then mix local.hex --force 2>/dev/null && mix archive.install hex credo --force 2>/dev/null || true; fi
fi
if command -v credo &>/dev/null; then
  credo "$TARGET" --format json 2>&1 | tee /tmp/credo-results.json
  check_exit ${PIPESTATUS[0]} "Credo"
else
  warn "Credo installation failed. Skipping."
fi

# --- Dialyxir ---
log "--- Dialyxir ---"
if ! command -v dialyxir &>/dev/null; then
  log "Installing Dialyxir..."
  if command -v mix &>/dev/null; then mix archive.install hex dialyxir --force 2>/dev/null || true; fi
fi
if command -v dialyxir &>/dev/null || (command -v mix &>/dev/null && mix help | grep -q dialyxir); then
  mix dialyzer 2>&1
  check_exit $? "Dialyxir"
else
  warn "Dialyxir installation failed. Skipping."
fi

# --- ElixirLS ---
log "--- ElixirLS ---"
if [[ -d ".elixir_ls" ]] || [[ -f ".elixir-ls" ]]; then
  log "ElixirLS config found. ElixirLS is typically run as an LSP server."
  log "For CLI linting, use Credo and Dialyxir instead."
else
  warn "ElixirLS is an LSP server. Skipping CLI lint."
fi

log "=== Elixir lint complete ==="
exit $EXIT_CODE
