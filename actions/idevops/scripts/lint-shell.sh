#!/usr/bin/env bash
# [iDevOps] Lint script for Shell scripts using ShellCheck and shfmt
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

has_shell() { find "$TARGET" -maxdepth 3 \( -name "*.sh" -o -name "*.bash" -o -name "*.zsh" \) -type f 2>/dev/null | head -1 | grep -q .; }

if ! has_shell; then
  warn "No shell files found. Skipping."
  exit 0
fi

# --- ShellCheck ---
log "--- ShellCheck ---"
if ! command -v shellcheck &>/dev/null; then
  log "Installing ShellCheck..."
  if command -v apt-get &>/dev/null; then sudo apt-get install -y shellcheck 2>/dev/null || true;
  elif command -v brew &>/dev/null; then brew install shellcheck 2>/dev/null || true;
  elif command -v dnf &>/dev/null; then sudo dnf install -y ShellCheck 2>/dev/null || true; fi
fi
if command -v shellcheck &>/dev/null; then
  find "$TARGET" -maxdepth 3 \( -name "*.sh" -o -name "*.bash" -o -name "*.zsh" \) -type f -exec shellcheck -f json {} + 2>&1 | tee /tmp/shellcheck-results.json
  check_exit ${PIPESTATUS[0]} "ShellCheck"
else
  warn "ShellCheck installation failed. Skipping."
fi

# --- shfmt ---
log "--- shfmt ---"
if ! command -v shfmt &>/dev/null; then
  log "Installing shfmt..."
  if command -v brew &>/dev/null; then brew install shfmt 2>/dev/null || true;
  elif command -v go &>/dev/null; then go install mvdan.cc/sh/v3/cmd/shfmt@latest 2>/dev/null || true; fi
fi
if command -v shfmt &>/dev/null; then
  find "$TARGET" -maxdepth 3 \( -name "*.sh" -o -name "*.bash" -o -name "*.zsh" \) -type f -exec shfmt -d {} + 2>&1
  check_exit $? "shfmt"
else
  warn "shfmt installation failed. Skipping."
fi

log "=== Shell lint complete ==="
exit $EXIT_CODE
