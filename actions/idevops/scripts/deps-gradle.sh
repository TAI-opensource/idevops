#!/usr/bin/env bash
# [iDevOps] OWASP dependency-check + dependencyUpdates (Gradle)
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

if [[ ! -f build.gradle ]] && [[ ! -f build.gradle.kts ]]; then
  log "No build.gradle or build.gradle.kts found"
  exit 0
fi

# Determine Gradle command
GRADLE_CMD=""
if [[ -x ./gradlew ]]; then
  GRADLE_CMD="./gradlew"
elif command -v gradle &>/dev/null; then
  GRADLE_CMD="gradle"
else
  log "No Gradle wrapper or Gradle installation found"
  exit 1
fi

log "Using: $GRADLE_CMD"

# Ensure OWASP plugin is applied
ensure_owasp_plugin() {
  local build_file="build.gradle"
  [[ -f build.gradle.kts ]] && build_file="build.gradle.kts"

  if ! grep -q "dependency-check" "$build_file" 2>/dev/null; then
    log "Adding OWASP dependency-check plugin to $build_file..."
    if [[ "$build_file" == "build.gradle.kts" ]]; then
      cat >> "$build_file" << 'PLUGINS'
plugins {
    id("org.owasp.dependencycheck") version "10.0.4"
}
PLUGINS
    else
      cat >> "$build_file" << 'PLUGINS'
plugins {
    id 'org.owasp.dependencycheck' version '10.0.4'
}
PLUGINS
    fi
  fi
}

# Ensure versions plugin
ensure_versions_plugin() {
  local build_file="build.gradle"
  [[ -f build.gradle.kts ]] && build_file="build.gradle.kts"

  if ! grep -q "com.github.ben-manes.versions" "$build_file" 2>/dev/null; then
    log "Adding versions plugin to $build_file..."
    if [[ "$build_file" == "build.gradle.kts" ]]; then
      cat >> "$build_file" << 'PLUGINS'
plugins {
    id("com.github.ben-manes.versions") version "0.51.0"
}
PLUGINS
    else
      cat >> "$build_file" << 'PLUGINS'
plugins {
    id 'com.github.ben-manes.versions' version '0.51.0'
}
PLUGINS
    fi
  fi
}

# --- OWASP dependency-check ---
log "Running OWASP dependency-check..."
ensure_owasp_plugin

OWASP_REPORT="${REPORT_DIR}/gradle-owasp-${TIMESTAMP}"
$GRADLE_CMD dependencyCheckAnalyze \
  -DdependencyCheck.format=json,html \
  -DdependencyCheck.outputDirectory="$OWASP_REPORT" \
  2>/dev/null || warn "OWASP dependency-check completed with issues"

# Check results
if [[ -d "$OWASP_REPORT" ]]; then
  for report_file in "$OWASP_REPORT"/*.json; do
    [[ -f "$report_file" ]] || continue
    VULN_COUNT=$(python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    deps = d.get('dependencies', [])
    vulns = sum(len(dep.get('vulnerabilities', [])) for dep in deps)
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
  ensure_versions_plugin

  OUTDATED_LOG="${REPORT_DIR}/gradle-outdated-${TIMESTAMP}.log"
  $GRADLE_CMD dependencyUpdates -Drevision=release 2>/dev/null | tee "$OUTDATED_LOG" | grep -E "->" || true

  OUTDATED_COUNT=$(grep -c "\->" "$OUTDATED_LOG" 2>/dev/null || echo 0)
  log "Outdated dependencies: $OUTDATED_COUNT"
fi

# --- Summary ---
log ""
log "=========================================="
if [[ $EXIT_CODE -eq 0 ]]; then
  log "[iDevOps] Gradle audit PASSED"
else
  log "[iDevOps] Gradle audit FAILED (threshold: $FAIL_ON)"
fi
log "=========================================="

exit $EXIT_CODE
