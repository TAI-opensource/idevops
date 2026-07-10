#!/usr/bin/env bash
# [iDevOps] cargo-audit + cargo outdated + cargo deny
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

if [[ ! -f Cargo.toml ]]; then
  log "No Cargo.toml found"
  exit 0
fi

log "Cargo project detected"

# --- Ensure tools ---
ensure_cargo_audit() {
  if ! command -v cargo-audit &>/dev/null; then
    log "Installing cargo-audit..."
    cargo install cargo-audit 2>/dev/null || warn "Failed to install cargo-audit"
  fi
}

ensure_cargo_outdated() {
  if ! command -v cargo-outdated &>/dev/null; then
    log "Installing cargo-outdated..."
    cargo install cargo-outdated 2>/dev/null || warn "Failed to install cargo-outdated"
  fi
}

# --- cargo audit ---
if [[ -f Cargo.lock ]]; then
  log "Running cargo audit..."
  ensure_cargo_audit

  AUDIT_JSON="${REPORT_DIR}/cargo-audit-${TIMESTAMP}.json"
  cargo audit --json > "$AUDIT_JSON" 2>/dev/null || true

  if [[ -f "$AUDIT_JSON" ]] && [[ -s "$AUDIT_JSON" ]]; then
    VULN_COUNT=$(python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    print(len(d.get('vulnerabilities', {}).get('list', [])))
except:
    print(0)
" < "$AUDIT_JSON" 2>/dev/null || echo 0)

    if [[ "$VULN_COUNT" -gt 0 ]]; then
      log "Found $VULN_COUNT vulnerabilities"
      bump_exit high

      python3 -c "
import sys, json
d = json.load(sys.stdin)
for v in d.get('vulnerabilities', {}).get('list', []):
    pkg = v.get('advisory', {}).get('package', 'unknown')
    sev = v.get('advisory', {}).get('severity', 'unknown')
    title = v.get('advisory', {}).get('title', 'N/A')
    print(f\"  {pkg} ({sev}): {title}\")
" < "$AUDIT_JSON" 2>/dev/null || true
    else
      log "No known vulnerabilities"
    fi
  fi
else
  warn "No Cargo.lock found, skipping audit"
fi

# --- cargo outdated ---
if [[ "$CHECK_OUTDATED" == "true" ]]; then
  log "Checking outdated dependencies..."
  ensure_cargo_outdated

  OUTDATED_JSON="${REPORT_DIR}/cargo-outdated-${TIMESTAMP}.json"
  cargo outdated --format json > "$OUTDATED_JSON" 2>/dev/null || true

  if [[ -f "$OUTDATED_JSON" ]] && [[ -s "$OUTDATED_JSON" ]]; then
    OUTDATED_COUNT=$(python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    count = 0
    for cat in d.get('dependencies', {}).values():
        count += len(cat)
    print(count)
except:
    print(0)
" < "$OUTDATED_JSON" 2>/dev/null || echo 0)
    log "Outdated packages: $OUTDATED_COUNT"
  fi
fi

# --- cargo deny (licenses + advisories) ---
if [[ "$CHECK_LICENSES" == "true" ]]; then
  log "Checking licenses with cargo-deny..."
  if command -v cargo-deny &>/dev/null; then
    cargo deny check licenses 2>/dev/null || warn "cargo-deny license check failed"
    cargo deny check advisories 2>/dev/null || warn "cargo-deny advisories check failed"
  else
    log "cargo-deny not installed, installing..."
    cargo install cargo-deny 2>/dev/null && {
      cargo deny check licenses 2>/dev/null || warn "cargo-deny license check failed"
    } || warn "Failed to install cargo-deny"
  fi
fi

# --- Summary ---
log ""
log "=========================================="
if [[ $EXIT_CODE -eq 0 ]]; then
  log "[iDevOps] Cargo audit PASSED"
else
  log "[iDevOps] Cargo audit FAILED (threshold: $FAIL_ON)"
fi
log "=========================================="

exit $EXIT_CODE
