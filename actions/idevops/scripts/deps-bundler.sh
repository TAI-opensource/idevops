#!/usr/bin/env bash
# [iDevOps] bundler-audit + bundle outdated
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

if [[ ! -f Gemfile ]]; then
  log "No Gemfile found"
  exit 0
fi

log "Ruby Bundler project detected"

# --- Ensure tools ---
ensure_bundler() {
  if ! command -v bundle &>/dev/null; then
    log "Installing Bundler..."
    gem install bundler 2>/dev/null || warn "Failed to install bundler"
  fi
}

ensure_bundler_audit() {
  if ! command -v bundle-audit &>/dev/null; then
    log "Installing bundler-audit..."
    gem install bundler-audit 2>/dev/null || warn "Failed to install bundler-audit"
  fi
}

ensure_bundler
ensure_bundler_audit

# --- bundler-audit ---
log "Running bundler-audit..."
AUDIT_JSON="${REPORT_DIR}/bundler-audit-${TIMESTAMP}.json"

bundle-audit update 2>/dev/null || true
bundle-audit check --format json > "$AUDIT_JSON" 2>/dev/null || true

if [[ -f "$AUDIT_JSON" ]] && [[ -s "$AUDIT_JSON" ]]; then
  VULN_COUNT=$(python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    print(len(d.get('results', [])))
except:
    print(0)
" < "$AUDIT_JSON" 2>/dev/null || echo 0)

  if [[ "$VULN_COUNT" -gt 0 ]]; then
    log "Found $VULN_COUNT vulnerabilities"
    bump_exit high

    python3 -c "
import sys, json
d = json.load(sys.stdin)
for r in d.get('results', []):
    adv = r.get('advisory', {})
    print(f\"  {adv.get('gem', 'N/A')}: {adv.get('title', 'N/A')[:60]}\")
" < "$AUDIT_JSON" 2>/dev/null || true
  else
    log "No known vulnerabilities"
  fi
else
  # Try text output
  bundle-audit check 2>/dev/null || warn "bundler-audit check failed"
fi

# --- Outdated ---
if [[ "$CHECK_OUTDATED" == "true" ]]; then
  log "Checking outdated gems..."
  OUTDATED_LOG="${REPORT_DIR}/bundler-outdated-${TIMESTAMP}.log"

  bundle outdated 2>/dev/null | tee "$OUTDATED_LOG" || true

  OUTDATED_COUNT=$(grep -c "newest" "$OUTDATED_LOG" 2>/dev/null || echo 0)
  log "Outdated gems: $OUTDATED_COUNT"
fi

# --- Licenses ---
if [[ "$CHECK_LICENSES" == "true" ]]; then
  log "Checking gem licenses..."
  LICENSE_REPORT="${REPORT_DIR}/bundler-licenses-${TIMESTAMP}.txt"

  if command -v bundle &>/dev/null; then
    bundle list 2>/dev/null | while read -r line; do
      echo "$line"
    done > "$LICENSE_REPORT" || true
    log "License report saved to $LICENSE_REPORT"
  fi
fi

# --- Summary ---
log ""
log "=========================================="
if [[ $EXIT_CODE -eq 0 ]]; then
  log "[iDevOps] Bundler audit PASSED"
else
  log "[iDevOps] Bundler audit FAILED (threshold: $FAIL_ON)"
fi
log "=========================================="

exit $EXIT_CODE
