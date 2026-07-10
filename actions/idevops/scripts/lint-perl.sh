#!/usr/bin/env bash
# [iDevOps] Lint script for Perl using perlcritic and perltidy
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

has_perl() { find "$TARGET" -maxdepth 3 \( -name "*.pl" -o -name "*.pm" -o -name "*.t" \) -type f 2>/dev/null | head -1 | grep -q .; }

if ! has_perl; then
  warn "No Perl files found. Skipping."
  exit 0
fi

# --- perlcritic ---
log "--- perlcritic ---"
if ! command -v perlcritic &>/dev/null; then
  log "Installing perlcritic..."
  if command -v cpanm &>/dev/null; then cpanm --notest Perl::Critic 2>/dev/null || true; fi
fi
if command -v perlcritic &>/dev/null; then
  find "$TARGET" -maxdepth 3 \( -name "*.pl" -o -name "*.pm" -o -name "*.t" \) -type f -exec perlcritic --severity 1 --verbose "%f:%l:%c: %m (%p, Severity: %s)\n" {} + 2>&1
  check_exit $? "perlcritic"
else
  warn "perlcritic installation failed. Skipping."
fi

# --- perltidy ---
log "--- perltidy ---"
if ! command -v perltidy &>/dev/null; then
  log "Installing perltidy..."
  if command -v cpanm &>/dev/null; then cpanm --notest Perl::Tidy 2>/dev/null || true; fi
fi
if command -v perltidy &>/dev/null; then
  find "$TARGET" -maxdepth 3 \( -name "*.pl" -o -name "*.pm" \) -type f -exec sh -c 'perltidy -b -bext=" " "$1" && diff "$1.bak" "$1"' _ {} \; 2>&1
  check_exit $? "perltidy"
else
  warn "perltidy installation failed. Skipping."
fi

log "=== Perl lint complete ==="
exit $EXIT_CODE
