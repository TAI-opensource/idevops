#!/usr/bin/env bash
# [iDevOps] dotnet list --vulnerable + dotnet list --outdated
set -euo pipefail

FAIL_ON="${FAIL_ON:-high}"
CHECK_OUTDATED="${CHECK_OUTDATED:-true}"
CHECK_LICENSES="${CHECK_LICENSES:-true}"
OUTPUT_FORMAT="${OUTPUT_FORMAT:-text}"
REPORT_DIR="${REPORT_DIR:-.}"
TIMESTAMP=$(date +%Y%m%dT%H%M%SZ)

log() { echo "[iDevOps] $*"; }
warn() { echo "[iDevOps] WARNING: $*" >&2; }

severity_level() {
  case "${1,,}" in
    critical) echo 4 ;; high) echo 3 ;; medium) echo 2 ;; low) echo 1 ;; *) echo 0 ;;
  esac
}

EXIT_CODE=0
FAIL_LEVEL=$(severity_level "$FAIL_ON")

bump_exit() {
  local level; level=$(severity_level "$1")
  [[ $level -ge $FAIL_LEVEL ]] && EXIT_CODE=1
}

# Find project files
CSPROJ_FILES=()
SOLUTION_FILES=()

while IFS= read -r f; do
  CSPROJ_FILES+=("$f")
done < <(find . -maxdepth 5 -name "*.csproj" 2>/dev/null)

while IFS= read -r f; do
  SOLUTION_FILES+=("$f")
done < <(find . -maxdepth 5 -name "*.sln" 2>/dev/null)

if [[ ${#CSPROJ_FILES[@]} -eq 0 ]] && [[ ${#SOLUTION_FILES[@]} -eq 0 ]]; then
  log "No .NET project or solution files found"
  exit 0
fi

log "Found ${#CSPROJ_FILES[@]} .csproj files, ${#SOLUTION_FILES[@]} .sln files"

# --- Ensure dotnet ---
if ! command -v dotnet &>/dev/null; then
  log "dotnet SDK not found, attempting install..."
  if command -v apt-get &>/dev/null; then
    wget -q https://packages.microsoft.com/config/ubuntu/$(lsb_release -rs)/packages-microsoft-prod.deb -O packages-microsoft-prod.deb 2>/dev/null
    sudo dpkg -i packages-microsoft-prod.deb 2>/dev/null
    sudo apt-get update -qq && sudo apt-get install -y -qq dotnet-sdk-8.0
  elif command -v yum &>/dev/null; then
    sudo rpm -Uvh https://packages.microsoft.com/config/centos/8/packages-microsoft-prod.rpm 2>/dev/null
    sudo yum install -y dotnet-sdk-8.0
  fi
fi

if ! command -v dotnet &>/dev/null; then
  log "Cannot proceed without dotnet SDK"
  exit 1
fi

# --- Vulnerable packages ---
log "Checking for vulnerable packages..."
VULNERABLE_LOG="${REPORT_DIR}/nuget-vulnerable-${TIMESTAMP}.txt"
TOTAL_VULNS=0

for proj in "${CSPROJ_FILES[@]}"; do
  log "  Scanning: $proj"
  dotnet list "$proj" package --vulnerable 2>/dev/null >> "$VULNERABLE_LOG" || true

  PROJ_VULNS=$(grep -c "has the following vulnerabilities" "$VULNERABLE_LOG" 2>/dev/null || echo 0)
  if [[ "$PROJ_VULNS" -gt 0 ]]; then
    TOTAL_VULNS=$((TOTAL_VULNS + PROJ_VULNS))
    bump_exit high
  fi
done

if [[ "$TOTAL_VULNS" -gt 0 ]]; then
  log "Found $TOTAL_VULNS projects with vulnerable packages"
  grep -A 3 "has the following vulnerabilities" "$VULNERABLE_LOG" 2>/dev/null || true
else
  log "No vulnerable packages found"
fi

# --- Outdated packages ---
if [[ "$CHECK_OUTDATED" == "true" ]]; then
  log "Checking outdated packages..."
  OUTDATED_LOG="${REPORT_DIR}/nuget-outdated-${TIMESTAMP}.txt"

  for proj in "${CSPROJ_FILES[@]}"; do
    log "  Checking: $proj"
    dotnet list "$proj" package --outdated 2>/dev/null >> "$OUTDATED_LOG" || true
  done

  OUTDATED_COUNT=$(grep -c "has newer" "$OUTDATED_LOG" 2>/dev/null || echo 0)
  log "Outdated packages: $OUTDATED_COUNT"
fi

# --- Licenses ---
if [[ "$CHECK_LICENSES" == "true" ]]; then
  log "Checking licenses..."
  LICENSE_LOG="${REPORT_DIR}/nuget-licenses-${TIMESTAMP}.txt"

  for proj in "${CSPROJ_FILES[@]}"; do
    log "  Checking licenses for: $proj"
    # dotnet doesn't have a built-in license command, use dotnet-project-licenses if available
    if command -v dotnet-project-licenses &>/dev/null; then
      dotnet-project-licenses -i "$proj" -o -j >> "$LICENSE_LOG" 2>/dev/null || true
    else
      log "  dotnet-project-licenses not installed, skipping license check"
      break
    fi
  done
fi

# --- Summary ---
log ""
log "=========================================="
if [[ $EXIT_CODE -eq 0 ]]; then
  log "[iDevOps] NuGet audit PASSED"
else
  log "[iDevOps] NuGet audit FAILED (threshold: $FAIL_ON)"
fi
log "=========================================="

exit $EXIT_CODE
