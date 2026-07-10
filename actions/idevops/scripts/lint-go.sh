#!/usr/bin/env bash
# [iDevOps] Lint script for Go using golangci-lint, go vet, staticcheck, and gofmt
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

if ! find "$TARGET" -maxdepth 3 -name "*.go" -type f 2>/dev/null | head -1 | grep -q .; then
  warn "No Go files found. Skipping."
  exit 0
fi

# --- golangci-lint ---
log "--- golangci-lint ---"
if ! command -v golangci-lint &>/dev/null; then
  log "Installing golangci-lint..."
  curl -sSfL https://raw.githubusercontent.com/golangci/golangci-lint/master/install.sh | sh -s -- -b /usr/local/bin 2>/dev/null || true
fi
if command -v golangci-lint &>/dev/null; then
  golangci-lint run --out-format=json "$TARGET" 2>&1 | tee /tmp/golangci-results.json
  check_exit ${PIPESTATUS[0]} "golangci-lint"
else
  warn "golangci-lint installation failed. Skipping."
fi

# --- go vet ---
log "--- go vet ---"
if command -v go &>/dev/null; then
  go vet ./... 2>&1
  check_exit $? "go vet"
else
  warn "go not found. Skipping."
fi

# --- staticcheck ---
log "--- staticcheck ---"
if ! command -v staticcheck &>/dev/null; then
  log "Installing staticcheck..."
  go install honnef.co/go/tools/cmd/staticcheck@latest 2>/dev/null || true
fi
if command -v staticcheck &>/dev/null; then
  staticcheck ./... 2>&1
  check_exit $? "staticcheck"
else
  warn "staticcheck installation failed. Skipping."
fi

# --- gofmt ---
log "--- gofmt ---"
if command -v gofmt &>/dev/null; then
  if gofmt -l -d "$TARGET" 2>&1 | grep -q .; then
    gofmt -l -d "$TARGET" 2>&1
    check_exit 1 "gofmt"
  else
    check_exit 0 "gofmt"
  fi
else
  warn "gofmt not found. Skipping."
fi

log "=== Go lint complete ==="
exit $EXIT_CODE
