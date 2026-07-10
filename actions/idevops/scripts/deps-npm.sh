#!/usr/bin/env bash
# [iDevOps] npm/yarn/pnpm Audit + Outdated + License Check
set -euo pipefail

FAIL_ON="${FAIL_ON:-high}"
CHECK_OUTDATED="${CHECK_OUTDATED:-true}"
CHECK_LICENSES="${CHECK_LICENSES:-true}"
OUTPUT_FORMAT="${OUTPUT_FORMAT:-text}"
REPORT_DIR="${REPORT_DIR:-.}"
TIMESTAMP=$(date +%Y%m%dT%H%M%SZ)

log() { echo "[iDevOps] $*"; }
warn() { echo "[iDevOps] WARNING: $*" >&2; }
err() { echo "[iDevOps] ERROR: $*" >&2; }

severity_level() {
  case "${1,,}" in
    critical) echo 4 ;; high) echo 3 ;; medium) echo 2 ;; low) echo 1 ;; *) echo 0 ;;
  esac
}

EXIT_CODE=0
FAIL_LEVEL=$(severity_level "$FAIL_ON")
TOTAL_VULNS=0

bump_exit() {
  local level; level=$(severity_level "$1")
  [[ $level -ge $FAIL_LEVEL ]] && EXIT_CODE=1
}

# --- Detect package manager ---
PKG_MANAGER=""
LOCK_FILE=""
if [[ -f pnpm-lock.yaml ]]; then
  PKG_MANAGER="pnpm"
  LOCK_FILE="pnpm-lock.yaml"
elif [[ -f yarn.lock ]]; then
  PKG_MANAGER="yarn"
  LOCK_FILE="yarn.lock"
elif [[ -f package-lock.json ]]; then
  PKG_MANAGER="npm"
  LOCK_FILE="package-lock.json"
fi

if [[ -z "$PKG_MANAGER" ]]; then
  log "No package manager lockfile detected (npm/yarn/pnpm)"
  exit 0
fi

log "Detected: $PKG_MANAGER ($LOCK_FILE)"

# --- Install tools ---
ensure_tools() {
  case "$PKG_MANAGER" in
    npm|pnpm)
      if ! command -v npm &>/dev/null; then
        log "Installing npm..."
        if command -v apt-get &>/dev/null; then
          sudo apt-get update -qq && sudo apt-get install -y -qq nodejs npm
        elif command -v yum &>/dev/null; then
          sudo yum install -y nodejs npm
        fi
      fi
      ;;
    yarn)
      if ! command -v yarn &>/dev/null; then
        log "Installing yarn..."
        npm install -g yarn 2>/dev/null || true
      fi
      ;;
  esac

  if [[ "$CHECK_LICENSES" == "true" ]] && ! command -v npx &>/dev/null && command -v npm &>/dev/null; then
    log "npx not found, license check will be skipped"
  fi
}

ensure_tools

# --- Audit ---
log "Running $PKG_MANAGER audit..."
AUDIT_JSON="${REPORT_DIR}/npm-audit-${TIMESTAMP}.json"

case "$PKG_MANAGER" in
  npm)
    npm audit --json > "$AUDIT_JSON" 2>/dev/null || true
    ;;
  yarn)
    yarn audit --json > "$AUDIT_JSON" 2>/dev/null || true
    ;;
  pnpm)
    pnpm audit --json > "$AUDIT_JSON" 2>/dev/null || true
    ;;
esac

# Parse results
if [[ -f "$AUDIT_JSON" ]] && [[ -s "$AUDIT_JSON" ]]; then
  VULN_SUMMARY=$(python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    meta = d.get('metadata', {}).get('vulnerabilities', {})
    total = sum(meta.values())
    print(json.dumps({
        'total': total,
        'critical': meta.get('critical', 0),
        'high': meta.get('high', 0),
        'moderate': meta.get('moderate', 0),
        'low': meta.get('low', 0),
        'info': meta.get('info', 0)
    }))
except:
    print(json.dumps({'total': 0, 'critical': 0, 'high': 0, 'moderate': 0, 'low': 0, 'info': 0}))
" < "$AUDIT_JSON" 2>/dev/null || echo '{"total":0}')

  TOTAL_VULNS=$(echo "$VULN_SUMMARY" | python3 -c "import sys,json; print(json.load(sys.stdin).get('total',0))")
  CRIT=$(echo "$VULN_SUMMARY" | python3 -c "import sys,json; print(json.load(sys.stdin).get('critical',0))")
  HIGH=$(echo "$VULN_SUMMARY" | python3 -c "import sys,json; print(json.load(sys.stdin).get('high',0))")
  MOD=$(echo "$VULN_SUMMARY" | python3 -c "import sys,json; print(json.load(sys.stdin).get('moderate',0))")
  LOW=$(echo "$VULN_SUMMARY" | python3 -c "import sys,json; print(json.load(sys.stdin).get('low',0))")

  log "Vulnerabilities: $TOTAL_VULNS total (critical: $CRIT, high: $HIGH, moderate: $MOD, low: $LOW)"

  if [[ "$CRIT" -gt 0 ]]; then bump_exit critical; fi
  if [[ "$HIGH" -gt 0 ]]; then bump_exit high; fi
  if [[ "$MOD" -gt 0 ]]; then bump_exit medium; fi
else
  log "No vulnerabilities found"
fi

# --- Outdated ---
if [[ "$CHECK_OUTDATED" == "true" ]]; then
  log "Checking outdated packages..."
  OUTDATED_JSON="${REPORT_DIR}/npm-outdated-${TIMESTAMP}.json"

  case "$PKG_MANAGER" in
    npm)
      npm outdated --json > "$OUTDATED_JSON" 2>/dev/null || true
      ;;
    yarn)
      yarn outdated --json > "$OUTDATED_JSON" 2>/dev/null || true
      ;;
    pnpm)
      pnpm outdated --json > "$OUTDATED_JSON" 2>/dev/null || true
      ;;
  esac

  if [[ -f "$OUTDATED_JSON" ]]; then
    OUTDATED_COUNT=$(python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    if isinstance(d, dict):
        print(len(d))
    else:
        print(0)
except:
    print(0)
" < "$OUTDATED_JSON" 2>/dev/null || echo 0)
    log "Outdated packages: $OUTDATED_COUNT"
  fi
fi

# --- Licenses ---
if [[ "$CHECK_LICENSES" == "true" ]] && command -v npx &>/dev/null; then
  log "Checking licenses..."
  LICENSE_JSON="${REPORT_DIR}/npm-licenses-${TIMESTAMP}.json"

  npx --yes license-checker --json --out "$LICENSE_JSON" 2>/dev/null || true

  if [[ -f "$LICENSE_JSON" ]]; then
    LICENSE_SUMMARY=$(python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    licenses = {}
    for pkg, info in d.items():
        lic = info.get('licenses', 'UNKNOWN')
        if isinstance(lic, list):
            lic = ', '.join(lic)
        licenses[lic] = licenses.get(lic, 0) + 1
    print(json.dumps(licenses, indent=2))
except:
    print('{}')
" < "$LICENSE_JSON" 2>/dev/null || echo "{}")
    log "License distribution:"
    echo "$LICENSE_SUMMARY" | head -20

    if [[ "$OUTPUT_FORMAT" == "json" ]]; then
      echo "$LICENSE_SUMMARY"
    fi
  fi
fi

# --- Summary ---
log ""
log "=========================================="
if [[ $EXIT_CODE -eq 0 ]]; then
  log "[iDevOps] npm audit PASSED"
else
  log "[iDevOps] npm audit FAILED (threshold: $FAIL_ON)"
fi
log "Report: $AUDIT_JSON"
log "=========================================="

exit $EXIT_CODE
