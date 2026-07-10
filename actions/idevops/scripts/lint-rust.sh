#!/usr/bin/env bash
# [iDevOps] Lint script for Rust using Clippy, rustfmt, and cargo-deny
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

if [[ ! -f "Cargo.toml" ]]; then
  warn "No Cargo.toml found. Skipping Rust lint."
  exit 0
fi

# --- Clippy ---
log "--- Clippy ---"
if command -v cargo &>/dev/null; then
  cargo clippy --all-targets --all-features -- -D warnings 2>&1
  check_exit $? "Clippy"
else
  warn "cargo not found. Install Rust toolchain."
fi

# --- rustfmt ---
log "--- rustfmt ---"
if command -v cargo &>/dev/null; then
  if cargo fmt -- --check 2>&1; then
    check_exit 0 "rustfmt"
  else
    check_exit 1 "rustfmt"
  fi
else
  warn "cargo not found. Skipping rustfmt."
fi

# --- cargo-deny ---
log "--- cargo-deny ---"
if ! command -v cargo-deny &>/dev/null; then
  log "Installing cargo-deny..."
  cargo install cargo-deny 2>/dev/null || true
fi
if command -v cargo-deny &>/dev/null; then
  cargo-deny check 2>&1
  check_exit $? "cargo-deny"
else
  warn "cargo-deny installation failed. Skipping."
fi

log "=== Rust lint complete ==="
exit $EXIT_CODE
