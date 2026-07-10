#!/usr/bin/env bash
# [iDevOps] Lint script for Scala using Scalafmt, Scalastyle, and WartRemover
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

has_scala() { find "$TARGET" -maxdepth 3 -name "*.scala" -type f 2>/dev/null | head -1 | grep -q .; }

if ! has_scala; then
  warn "No Scala files found. Skipping."
  exit 0
fi

# --- Scalafmt ---
log "--- Scalafmt ---"
if ! command -v scalafmt &>/dev/null; then
  log "Installing Scalafmt..."
  if command -v cs &>/dev/null; then
    cs install scalafmt 2>/dev/null || true
  elif command -v brew &>/dev/null; then
    brew install scalafmt 2>/dev/null || true
  fi
fi
if command -v scalafmt &>/dev/null; then
  if scalafmt --check "$TARGET" 2>&1; then
    check_exit 0 "Scalafmt"
  else
    check_exit $? "Scalafmt"
  fi
else
  warn "Scalafmt installation failed. Skipping."
fi

# --- Scalastyle ---
log "--- Scalastyle ---"
if [[ -f "build.sbt" ]]; then
  if command -v sbt &>/dev/null; then
    sbt scalastyle 2>&1
    check_exit $? "Scalastyle"
  else
    warn "sbt not found. Skipping Scalastyle."
  fi
else
  warn "No build.sbt found. Skipping Scalastyle."
fi

# --- WartRemover ---
log "--- WartRemover ---"
if [[ -f "build.sbt" ]]; then
  if command -v sbt &>/dev/null; then
    sbt wartRemover 2>&1
    check_exit $? "WartRemover"
  else
    warn "sbt not found. Skipping WartRemover."
  fi
else
  warn "No build.sbt found. Skipping WartRemover."
fi

log "=== Scala lint complete ==="
exit $EXIT_CODE
