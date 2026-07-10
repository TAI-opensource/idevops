#!/usr/bin/env bash
# [iDevOps] govulncheck + go list -u -m all + go-licenses
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

if [[ ! -f go.mod ]]; then
  log "No go.mod found"
  exit 0
fi

MODULE_NAME=$(grep "^module" go.mod | awk '{print $2}')
log "Go module: $MODULE_NAME"

# --- Ensure tools ---
ensure_govulncheck() {
  if ! command -v govulncheck &>/dev/null; then
    log "Installing govulncheck..."
    go install golang.org/x/vuln/cmd/govulncheck@latest 2>/dev/null || warn "Failed to install govulncheck"
  fi
}

# --- govulncheck ---
log "Running govulncheck..."
ensure_govulncheck

VULN_JSON="${REPORT_DIR}/go-vuln-${TIMESTAMP}.json"

if command -v govulncheck &>/dev/null; then
  govulncheck -json ./... > "$VULN_JSON" 2>/dev/null || true

  if [[ -f "$VULN_JSON" ]] && [[ -s "$VULN_JSON" ]]; then
    VULN_COUNT=$(python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    print(len(d.get('vulns', [])))
except:
    print(0)
" < "$VULN_JSON" 2>/dev/null || echo 0)

    if [[ "$VULN_COUNT" -gt 0 ]]; then
      log "Found $VULN_COUNT vulnerabilities"
      bump_exit high

      python3 -c "
import sys, json
d = json.load(sys.stdin)
for v in d.get('vulns', []):
    osv = v.get('osv', {})
    alias = osv.get('id', 'N/A')
    summary = osv.get('summary', 'N/A')[:80]
    print(f\"  {alias}: {summary}\")
" < "$VULN_JSON" 2>/dev/null || true
    else
      log "No known vulnerabilities"
    fi
  fi
else
  warn "govulncheck not available"
fi

# --- Outdated ---
if [[ "$CHECK_OUTDATED" == "true" ]]; then
  log "Checking outdated modules..."
  OUTDATED_JSON="${REPORT_DIR}/go-outdated-${TIMESTAMP}.json"

  go list -u -m -json all > "$OUTDATED_JSON" 2>/dev/null || true

  if [[ -f "$OUTDATED_JSON" ]]; then
    OUTDATED_COUNT=$(python3 -c "
import sys, json
try:
    data = sys.stdin.read()
    count = 0
    decoder = json.JSONDecoder()
    idx = 0
    while idx < len(data):
        data_stripped = data[idx:].lstrip()
        if not data_stripped:
            break
        idx = len(data) - len(data_stripped)
        obj, end = decoder.raw_decode(data, idx)
        idx += end
        if obj.get('Update'):
            count += 1
    print(count)
except:
    print(0)
" < "$OUTDATED_JSON" 2>/dev/null || echo 0)
    log "Outdated modules: $OUTDATED_COUNT"
  fi
fi

# --- Licenses ---
if [[ "$CHECK_LICENSES" == "true" ]]; then
  log "Checking licenses..."
  if command -v go-licenses &>/dev/null; then
    LICENSE_REPORT="${REPORT_DIR}/go-licenses-${TIMESTAMP}"
    go-licenses report ./... > "${LICENSE_REPORT}.csv" 2>/dev/null || warn "go-licenses report failed"
  else
    log "go-licenses not installed, installing..."
    go install github.com/google/go-licenses@latest 2>/dev/null && {
      LICENSE_REPORT="${REPORT_DIR}/go-licenses-${TIMESTAMP}"
      go-licenses report ./... > "${LICENSE_REPORT}.csv" 2>/dev/null || warn "go-licenses report failed"
    } || warn "Failed to install go-licenses"
  fi
fi

# --- Summary ---
log ""
log "=========================================="
if [[ $EXIT_CODE -eq 0 ]]; then
  log "[iDevOps] Go audit PASSED"
else
  log "[iDevOps] Go audit FAILED (threshold: $FAIL_ON)"
fi
log "=========================================="

exit $EXIT_CODE
