#!/usr/bin/env bash
# [iDevOps] composer audit + composer outdated
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

if [[ ! -f composer.json ]]; then
  log "No composer.json found"
  exit 0
fi

log "PHP Composer project detected"

# --- Ensure composer ---
if ! command -v composer &>/dev/null; then
  log "Installing Composer..."
  if command -v apt-get &>/dev/null; then
    sudo apt-get update -qq && sudo apt-get install -y -qq composer
  elif command -v php &>/dev/null; then
    php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');"
    php composer-setup.php --install-dir=/usr/local/bin --filename=composer
    rm composer-setup.php
  fi
fi

if ! command -v composer &>/dev/null; then
  log "Cannot proceed without Composer"
  exit 1
fi

# --- composer audit ---
log "Running composer audit..."
AUDIT_JSON="${REPORT_DIR}/composer-audit-${TIMESTAMP}.json"

composer audit --format=json > "$AUDIT_JSON" 2>/dev/null || true

if [[ -f "$AUDIT_JSON" ]] && [[ -s "$AUDIT_JSON" ]]; then
  VULN_COUNT=$(python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    total = 0
    for pkg in d.get('installed', []):
        total += len(pkg.get('vulnerabilities', []))
    print(total)
except:
    print(0)
" < "$AUDIT_JSON" 2>/dev/null || echo 0)

  if [[ "$VULN_COUNT" -gt 0 ]]; then
    log "Found $VULN_COUNT vulnerabilities"
    bump_exit high

    python3 -c "
import sys, json
d = json.load(sys.stdin)
for pkg in d.get('installed', []):
    for v in pkg.get('vulnerabilities', []):
        print(f\"  {pkg['name']}: {v.get('title', 'N/A')[:60]}\")
" < "$AUDIT_JSON" 2>/dev/null || true
  else
    log "No known vulnerabilities"
  fi
else
  # Try text output as fallback
  composer audit 2>/dev/null || warn "composer audit failed"
fi

# --- Outdated ---
if [[ "$CHECK_OUTDATED" == "true" ]]; then
  log "Checking outdated packages..."
  OUTDATED_JSON="${REPORT_DIR}/composer-outdated-${TIMESTAMP}.json"

  composer outdated --direct --format=json > "$OUTDATED_JSON" 2>/dev/null || true

  if [[ -f "$OUTDATED_JSON" ]] && [[ -s "$OUTDATED_JSON" ]]; then
    OUTDATED_COUNT=$(python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    print(len(d.get('installed', [])))
except:
    print(0)
" < "$OUTDATED_JSON" 2>/dev/null || echo 0)
    log "Outdated packages: $OUTDATED_COUNT"
  fi
fi

# --- Licenses ---
if [[ "$CHECK_LICENSES" == "true" ]]; then
  log "Checking licenses..."
  LICENSE_JSON="${REPORT_DIR}/composer-licenses-${TIMESTAMP}.json"

  composer licenses --format=json > "$LICENSE_JSON" 2>/dev/null || true

  if [[ -f "$LICENSE_JSON" ]] && [[ -s "$LICENSE_JSON" ]]; then
    LICENSE_SUMMARY=$(python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    licenses = {}
    for pkg in d.get('installed', []):
        lic = pkg.get('license', ['UNKNOWN'])
        if isinstance(lic, list):
            lic = ', '.join(lic)
        licenses[lic] = licenses.get(lic, 0) + 1
    for lic, count in sorted(licenses.items(), key=lambda x: -x[1]):
        print(f\"  {lic}: {count} packages\")
except:
    print('  Failed to parse licenses')
" < "$LICENSE_JSON" 2>/dev/null)
    log "$LICENSE_SUMMARY"
  fi
fi

# --- Summary ---
log ""
log "=========================================="
if [[ $EXIT_CODE -eq 0 ]]; then
  log "[iDevOps] Composer audit PASSED"
else
  log "[iDevOps] Composer audit FAILED (threshold: $FAIL_ON)"
fi
log "=========================================="

exit $EXIT_CODE
