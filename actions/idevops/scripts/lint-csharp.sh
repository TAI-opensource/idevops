#!/usr/bin/env bash
# [iDevOps] Lint script for C# using dotnet format and Roslyn analyzers
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

has_cs() { find "$TARGET" -maxdepth 3 -name "*.cs" -type f 2>/dev/null | head -1 | grep -q .; }
has_sln() { find "$TARGET" -maxdepth 2 -name "*.sln" -type f 2>/dev/null | head -1 | grep -q .; }

if ! has_cs; then
  warn "No C# files found. Skipping."
  exit 0
fi

# --- dotnet format ---
log "--- dotnet format ---"
if command -v dotnet &>/dev/null; then
  if has_sln; then
    SLN_FILE=$(find "$TARGET" -maxdepth 2 -name "*.sln" -type f | head -1)
    dotnet format "$SLN_FILE" --verify-no-changes --verbosity diagnostic 2>&1
    check_exit $? "dotnet format"
  elif find "$TARGET" -maxdepth 2 -name "*.csproj" -type f 2>/dev/null | head -1 | grep -q .; then
    CSPROJ_FILE=$(find "$TARGET" -maxdepth 2 -name "*.csproj" -type f | head -1)
    dotnet format "$CSPROJ_FILE" --verify-no-changes --verbosity diagnostic 2>&1
    check_exit $? "dotnet format"
  else
    warn "No .sln or .csproj found. Skipping dotnet format."
  fi
else
  warn "dotnet not found. Skipping."
fi

# --- Roslyn analyzers (via dotnet build) ---
log "--- Roslyn analyzers ---"
if command -v dotnet &>/dev/null; then
  if has_sln; then
    SLN_FILE=$(find "$TARGET" -maxdepth 2 -name "*.sln" -type f | head -1)
    dotnet build "$SLN_FILE" -warnaserror -p:TreatWarningsAsErrors=true 2>&1
    check_exit $? "Roslyn analyzers"
  elif find "$TARGET" -maxdepth 2 -name "*.csproj" -type f 2>/dev/null | head -1 | grep -q .; then
    CSPROJ_FILE=$(find "$TARGET" -maxdepth 2 -name "*.csproj" -type f | head -1)
    dotnet build "$CSPROJ_FILE" -warnaserror -p:TreatWarningsAsErrors=true 2>&1
    check_exit $? "Roslyn analyzers"
  else
    warn "No .sln or .csproj found. Skipping Roslyn analyzers."
  fi
else
  warn "dotnet not found. Skipping."
fi

log "=== C# lint complete ==="
exit $EXIT_CODE
