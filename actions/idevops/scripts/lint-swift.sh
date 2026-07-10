#!/usr/bin/env bash
# [iDevOps] Lint script for Swift using SwiftLint and SwiftFormat
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

has_swift() { find "$TARGET" -maxdepth 3 -name "*.swift" -type f 2>/dev/null | head -1 | grep -q .; }

if ! has_swift; then
  warn "No Swift files found. Skipping."
  exit 0
fi

# --- SwiftLint ---
log "--- SwiftLint ---"
if ! command -v swiftlint &>/dev/null; then
  log "Installing SwiftLint..."
  if command -v brew &>/dev/null; then brew install swiftlint 2>/dev/null || true; fi
fi
if command -v swiftlint &>/dev/null; then
  swiftlint lint --reporter json "$TARGET" 2>&1 | tee /tmp/swiftlint-results.json
  check_exit ${PIPESTATUS[0]} "SwiftLint"
else
  warn "SwiftLint installation failed. Skipping."
fi

# --- SwiftFormat ---
log "--- SwiftFormat ---"
if ! command -v swiftformat &>/dev/null; then
  log "Installing SwiftFormat..."
  if command -v brew &>/dev/null; then brew install swiftformat 2>/dev/null || true; fi
fi
if command -v swiftformat &>/dev/null; then
  if swiftformat --lint "$TARGET" 2>&1; then
    check_exit 0 "SwiftFormat"
  else
    check_exit $? "SwiftFormat"
  fi
else
  warn "SwiftFormat installation failed. Skipping."
fi

log "=== Swift lint complete ==="
exit $EXIT_CODE
