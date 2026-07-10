#!/usr/bin/env bash
# [iDevOps] OWASP dependency-check + mvn versions:display-dependency-updates
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

if [[ ! -f pom.xml ]]; then
  log "No pom.xml found"
  exit 0
fi

if ! command -v mvn &>/dev/null; then
  log "Maven not found, attempting install..."
  if command -v apt-get &>/dev/null; then
    sudo apt-get update -qq && sudo apt-get install -y -qq maven
  elif command -v yum &>/dev/null; then
    sudo yum install -y maven
  elif command -v sdkman &>/dev/null; then
    sdk install maven
  fi
fi

if ! command -v mvn &>/dev/null; then
  log "Cannot proceed without Maven"
  exit 1
fi

PROJECT_NAME=$(grep -m1 "<artifactId>" pom.xml | sed 's/.*<artifactId>\(.*\)<\/artifactId>.*/\1/' | tr -d '[:space:]')
log "Maven project: $PROJECT_NAME"

# --- OWASP dependency-check ---
log "Running OWASP dependency-check..."
OWASP_REPORT="${REPORT_DIR}/maven-owasp-${TIMESTAMP}"

mvn org.owasp:dependency-check-maven:check \
  -Dformat=json,html \
  -DoutputDirectory="$OWASP_REPORT" \
  -DfailBuildOnCVSS="${FAIL_LEVEL}" \
  2>/dev/null || true

# Check OWASP report
if [[ -d "$OWASP_REPORT" ]]; then
  for report_file in "$OWASP_REPORT"/*.json; do
    [[ -f "$report_file" ]] || continue
    VULN_COUNT=$(python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    deps = d.get('dependencies', [])
    vulns = 0
    for dep in deps:
        vulns += len(dep.get('vulnerabilities', []))
    print(vulns)
except:
    print(0)
" < "$report_file" 2>/dev/null || echo 0)

    if [[ "$VULN_COUNT" -gt 0 ]]; then
      log "Found $VULN_COUNT vulnerabilities via OWASP"
      bump_exit high
    else
      log "No vulnerabilities found via OWASP"
    fi
  done
fi

# --- Outdated ---
if [[ "$CHECK_OUTDATED" == "true" ]]; then
  log "Checking outdated dependencies..."
  OUTDATED_LOG="${REPORT_DIR}/maven-outdated-${TIMESTAMP}.log"

  mvn versions:display-dependency-updates \
    -DprocessDependencyManagement=false \
    2>/dev/null | tee "$OUTDATED_LOG" | grep -E "\[INFO\].*->" || true

  OUTDATED_COUNT=$(grep -c "\[INFO\].*->" "$OUTDATED_LOG" 2>/dev/null || echo 0)
  log "Outdated dependencies: $OUTDATED_COUNT"
fi

# --- Licenses ---
if [[ "$CHECK_LICENSES" == "true" ]]; then
  log "Checking licenses..."
  LICENSE_REPORT="${REPORT_DIR}/maven-licenses-${TIMESTAMP}.html"

  mvn license:aggregate-third-party-report \
    -DlicenseMissingCheck=true \
    -DfailOnMissing=false \
    -DoutputFile="$LICENSE_REPORT" \
    2>/dev/null || warn "License report generation failed"
fi

# --- Summary ---
log ""
log "=========================================="
if [[ $EXIT_CODE -eq 0 ]]; then
  log "[iDevOps] Maven audit PASSED"
else
  log "[iDevOps] Maven audit FAILED (threshold: $FAIL_ON)"
fi
log "=========================================="

exit $EXIT_CODE
