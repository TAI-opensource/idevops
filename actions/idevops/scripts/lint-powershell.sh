#!/usr/bin/env bash
# [iDevOps] Lint script for PowerShell using PSScriptAnalyzer
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

has_ps() { find "$TARGET" -maxdepth 3 \( -name "*.ps1" -o -name "*.psm1" -o -name "*.psd1" \) -type f 2>/dev/null | head -1 | grep -q .; }

if ! has_ps; then
  warn "No PowerShell files found. Skipping."
  exit 0
fi

# --- PSScriptAnalyzer ---
log "--- PSScriptAnalyzer ---"
if command -v pwsh &>/dev/null; then
  pwsh -Command '
    if (!(Get-Module -ListAvailable -Name PSScriptAnalyzer)) {
        Write-Host "[iDevOps] Installing PSScriptAnalyzer..."
        Install-Module -Name PSScriptAnalyzer -Force -Scope CurrentUser -SkipPublisherCheck
    }
    Import-Module PSScriptAnalyzer
    $results = Invoke-ScriptAnalyzer -Path "'${TARGET}'" -Recurse -ReportSummary
    $results | ConvertTo-Json -Depth 5 | Out-File /tmp/psscriptanalyzer-results.json
    if ($results.Count -gt 0) {
        $results | Format-Table -AutoSize
        exit 1
    }
    exit 0
  ' 2>&1
  check_exit $? "PSScriptAnalyzer"
else
  warn "pwsh (PowerShell Core) not found. Skipping."
fi

log "=== PowerShell lint complete ==="
exit $EXIT_CODE
