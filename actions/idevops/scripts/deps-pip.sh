#!/usr/bin/env bash
# [iDevOps] pip-audit + pip list --outdated + pip-licenses
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

# Detect Python dependency files
REQ_FILES=()
[[ -f requirements.txt ]] && REQ_FILES+=(requirements.txt)
[[ -f setup.py ]] && REQ_FILES+=(setup.py)
[[ -f setup.cfg ]] && REQ_FILES+=(setup.cfg)
[[ -f pyproject.toml ]] && REQ_FILES+=(pyproject.toml)
[[ -f Pipfile ]] && REQ_FILES+=(Pipfile)

if [[ ${#REQ_FILES[@]} -eq 0 ]]; then
  log "No Python dependency files found"
  exit 0
fi

log "Python dependency files: ${REQ_FILES[*]}"

# --- Ensure tools ---
install_pip_audit() {
  if ! command -v pip-audit &>/dev/null; then
    log "Installing pip-audit..."
    pip install pip-audit -q 2>/dev/null
  fi
}

install_pip_licenses() {
  if ! command -v pip-licenses &>/dev/null; then
    log "Installing pip-licenses..."
    pip install pip-licenses -q 2>/dev/null
  fi
}

# --- pip-audit ---
log "Running pip-audit..."
AUDIT_JSON="${REPORT_DIR}/pip-audit-${TIMESTAMP}.json"

install_pip_audit

if command -v pip-audit &>/dev/null; then
  pip-audit --format json --output "$AUDIT_JSON" 2>/dev/null || true

  if [[ -f "$AUDIT_JSON" ]]; then
    VULN_COUNT=$(python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    vulns = [v for v in d if v.get('vulns')]
    print(len(vulns))
except:
    print(0)
" < "$AUDIT_JSON" 2>/dev/null || echo 0)

    if [[ "$VULN_COUNT" -gt 0 ]]; then
      log "Found $VULN_COUNT packages with vulnerabilities"
      bump_exit high

      # Print details
      python3 -c "
import sys, json
d = json.load(sys.stdin)
for pkg in d:
    for vuln in pkg.get('vulns', []):
        print(f\"  {pkg['name']}=={pkg['version']}: {vuln.get('id', 'N/A')} - {vuln.get('description', 'N/A')[:80]}\")
" < "$AUDIT_JSON" 2>/dev/null || true
    else
      log "No known vulnerabilities"
    fi
  fi
else
  warn "pip-audit not available"
fi

# --- Outdated ---
if [[ "$CHECK_OUTDATED" == "true" ]]; then
  log "Checking outdated packages..."
  OUTDATED_JSON="${REPORT_DIR}/pip-outdated-${TIMESTAMP}.json"

  pip list --outdated --format json > "$OUTDATED_JSON" 2>/dev/null || true

  if [[ -f "$OUTDATED_JSON" ]]; then
    OUTDATED_COUNT=$(python3 -c "
import sys, json
try:
    print(len(json.load(sys.stdin)))
except:
    print(0)
" < "$OUTDATED_JSON" 2>/dev/null || echo 0)
    log "Outdated packages: $OUTDATED_COUNT"

    if [[ "$OUTDATED_COUNT" -gt 0 ]]; then
      python3 -c "
import sys, json
d = json.load(sys.stdin)
for pkg in d[:20]:
    print(f\"  {pkg['name']}: {pkg['version']} -> {pkg['latest_version']} ({pkg['latest_filetype']})\")
if len(d) > 20:
    print(f'  ... and {len(d) - 20} more')
" < "$OUTDATED_JSON" 2>/dev/null || true
    fi
  fi
fi

# --- Licenses ---
if [[ "$CHECK_LICENSES" == "true" ]]; then
  log "Checking licenses..."
  LICENSE_JSON="${REPORT_DIR}/pip-licenses-${TIMESTAMP}.json"

  install_pip_licenses

  if command -v pip-licenses &>/dev/null; then
    pip-licenses --format=json --output-file="$LICENSE_JSON" 2>/dev/null || true

    if [[ -f "$LICENSE_JSON" ]]; then
      LICENSE_SUMMARY=$(python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    licenses = {}
    for pkg in d:
        lic = pkg.get('License', 'UNKNOWN')
        licenses[lic] = licenses.get(lic, 0) + 1
    for lic, count in sorted(licenses.items(), key=lambda x: -x[1]):
        print(f\"  {lic}: {count} packages\")
except:
    print('  Failed to parse licenses')
" < "$LICENSE_JSON" 2>/dev/null)
      log "$LICENSE_SUMMARY"
    fi
  else
    warn "pip-licenses not available"
  fi
fi

# --- Summary ---
log ""
log "=========================================="
if [[ $EXIT_CODE -eq 0 ]]; then
  log "[iDevOps] pip audit PASSED"
else
  log "[iDevOps] pip audit FAILED (threshold: $FAIL_ON)"
fi
log "=========================================="

exit $EXIT_CODE
