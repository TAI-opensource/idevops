#!/usr/bin/env bash
# [iDevOps] Lint script for Julia using JuliaFormatter
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

has_julia() { find "$TARGET" -maxdepth 3 -name "*.jl" -type f 2>/dev/null | head -1 | grep -q .; }

if ! has_julia; then
  warn "No Julia files found. Skipping."
  exit 0
fi

# --- JuliaFormatter ---
log "--- JuliaFormatter ---"
if command -v julia &>/dev/null; then
  julia -e '
    using Pkg
    if !Base.find_package("JuliaFormatter") !== nothing
        Pkg.add("JuliaFormatter")
    end
    using JuliaFormatter
    results = format("'${TARGET}'", dry_run=true)
    if results != 1
        println("JuliaFormatter: formatting issues found")
        exit(1)
    end
  ' 2>&1
  check_exit $? "JuliaFormatter"
else
  warn "julia not found. Skipping."
fi

log "=== Julia lint complete ==="
exit $EXIT_CODE
