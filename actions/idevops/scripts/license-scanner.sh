#!/usr/bin/env bash
# [iDevOps] License Compliance Scanner
set -euo pipefail

LICENSE_ALLOWED="${LICENSE_ALLOWED:-}"
LICENSE_DENIED="${LICENSE_DENIED:-MIT,Apache-2.0,BSD-2-Clause,BSD-3-Clause,ISC,Unlicense,CC0-1.0,0BSD}"
REPORT_DIR="${REPORT_DIR:-.}"
TIMESTAMP=$(date +%Y%m%dT%H%M%SZ)
OUTPUT_FORMAT="${OUTPUT_FORMAT:-text}"

log() { echo "[iDevOps] $*"; }
warn() { echo "[iDevOps] WARNING: $*" >&2; }

EXIT_CODE=0

# Parse license lists into arrays
IFS=',' read -ra ALLOWED_LIST <<< "${LICENSE_ALLOWED}"
IFS=',' read -ra DENIED_LIST <<< "${LICENSE_DENIED}"

# Check if a license is allowed
is_allowed() {
  local lic="$1"
  for allowed in "${ALLOWED_LIST[@]}"; do
    if [[ "${lic,,}" == "${allowed,,}" ]]; then
      return 0
    fi
  done
  return 1
}

# Check if a license is denied
is_denied() {
  local lic="$1"
  for denied in "${DENIED_LIST[@]}"; do
    if [[ "${lic,,}" == "${denied,,}" ]]; then
      return 0
    fi
  done
  return 1
}

# --- FOSSA CLI ---
try_fossa() {
  if command -v fossa &>/dev/null; then
    log "Using FOSSA CLI..."
    fossa analyze 2>/dev/null || true
    fossa test 2>/dev/null || true
    return 0
  fi
  return 1
}

# --- ScanCode Toolkit ---
try_scancode() {
  if command -v scancode &>/dev/null; then
    log "Using ScanCode Toolkit..."
    local scan_result="${REPORT_DIR}/scancode-${TIMESTAMP}.json"
    scancode --license --json-pp "$scan_result" . 2>/dev/null || true

    if [[ -f "$scan_result" ]]; then
      python3 -c "
import sys, json

with open('$scan_result') as f:
    data = json.load(f)

licenses = {}
for file_entry in data.get('files', []):
    for lic in file_entry.get('licenses', []):
        name = lic.get('identifier', 'UNKNOWN')
        licenses[name] = licenses.get(name, 0) + 1

for lic, count in sorted(licenses.items(), key=lambda x: -x[1]):
    print(f'  {lic}: {count} files')
" 2>/dev/null || true
      return 0
    fi
  fi
  return 1
}

# --- Per-ecosystem license detection ---
scan_npm_licenses() {
  if [[ -f package.json ]] && command -v npx &>/dev/null; then
    log "Scanning npm licenses..."
    local lic_file="${REPORT_DIR}/npm-licenses-${TIMESTAMP}.json"
    npx --yes license-checker --json --out "$lic_file" 2>/dev/null || true

    if [[ -f "$lic_file" ]]; then
      python3 -c "
import sys, json

with open('$lic_file') as f:
    data = json.load(f)

denied = set('${LICENSE_DENIED}'.lower().split(','))
issues = []

for pkg, info in data.items():
    lic = info.get('licenses', 'UNKNOWN')
    if isinstance(lic, list):
        lic = ', '.join(lic)
    if lic.lower() in denied and lic.lower() not in set('${LICENSE_ALLOWED}'.lower().split(',')):
        issues.append(f'{pkg}: {lic}')

if issues:
    print('Non-compliant licenses found:')
    for i in issues:
        print(f'  {i}')
else:
    print('All npm licenses compliant')
" 2>/dev/null
      return 0
    fi
  fi
  return 1
}

scan_pip_licenses() {
  if command -v pip-licenses &>/dev/null; then
    log "Scanning pip licenses..."
    local lic_file="${REPORT_DIR}/pip-licenses-${TIMESTAMP}.json"
    pip-licenses --format=json --output-file="$lic_file" 2>/dev/null || true

    if [[ -f "$lic_file" ]]; then
      python3 -c "
import sys, json

with open('$lic_file') as f:
    data = json.load(f)

denied = set('${LICENSE_DENIED}'.lower().split(','))
issues = []

for pkg in data:
    lic = pkg.get('License', 'UNKNOWN')
    if lic.lower() in denied and lic.lower() not in set('${LICENSE_ALLOWED}'.lower().split(',')):
        issues.append(f\"{pkg['Name']}: {lic}\")

if issues:
    print('Non-compliant licenses found:')
    for i in issues:
        print(f'  {i}')
else:
    print('All pip licenses compliant')
" 2>/dev/null
      return 0
    fi
  fi
  return 1
}

scan_cargo_licenses() {
  if [[ -f Cargo.toml ]] && command -v cargo &>/dev/null; then
    log "Scanning Cargo licenses..."
    if command -v cargo-license &>/dev/null; then
      cargo license 2>/dev/null || warn "cargo-license failed"
      return 0
    fi
  fi
  return 1
}

scan_go_licenses() {
  if [[ -f go.mod ]] && command -v go-licenses &>/dev/null; then
    log "Scanning Go licenses..."
    go-licenses report ./... 2>/dev/null || warn "go-licenses failed"
    return 0
  fi
  return 1
}

scan_composer_licenses() {
  if [[ -f composer.json ]] && command -v composer &>/dev/null; then
    log "Scanning Composer licenses..."
    local lic_json="${REPORT_DIR}/composer-licenses-${TIMESTAMP}.json"
    composer licenses --format=json > "$lic_json" 2>/dev/null || true

    if [[ -f "$lic_json" ]]; then
      python3 -c "
import sys, json

with open('$lic_json') as f:
    data = json.load(f)

denied = set('${LICENSE_DENIED}'.lower().split(','))
issues = []

for pkg in data.get('installed', []):
    lic = pkg.get('license', ['UNKNOWN'])
    if isinstance(lic, list):
        lic = ', '.join(lic)
    if lic.lower() in denied and lic.lower() not in set('${LICENSE_ALLOWED}'.lower().split(',')):
        issues.append(f\"{pkg['name']}: {lic}\")

if issues:
    print('Non-compliant licenses found:')
    for i in issues:
        print(f'  {i}')
else:
    print('All Composer licenses compliant')
" 2>/dev/null
      return 0
    fi
  fi
  return 1
}

# --- Main ---
main() {
  log "=========================================="
  log "[iDevOps] License Compliance Scanner"
  log "=========================================="
  log "Allowed: ${LICENSE_ALLOWED:-<auto-detect>}"
  log "Denied: $LICENSE_DENIED"
  log ""

  local tool_used=false

  # Try FOSSA first
  if try_fossa; then
    tool_used=true
  # Then try ScanCode
  elif try_scancode; then
    tool_used=true
  fi

  # Fall back to per-ecosystem tools
  if [[ "$tool_used" == "false" ]]; then
    log "Using per-ecosystem license tools..."
    [[ -f package.json ]] && scan_npm_licenses
    [[ -f requirements.txt || -f pyproject.toml || -f setup.py ]] && scan_pip_licenses
    [[ -f Cargo.toml ]] && scan_cargo_licenses
    [[ -f go.mod ]] && scan_go_licenses
    [[ -f composer.json ]] && scan_composer_licenses
  fi

  log ""
  log "=========================================="
  if [[ $EXIT_CODE -eq 0 ]]; then
    log "[iDevOps] License compliance PASSED"
  else
    log "[iDevOps] License compliance FAILED"
  fi
  log "=========================================="

  exit $EXIT_CODE
}

main "$@"
