#!/usr/bin/env bash
# [iDevOps] Lint script for Java using Checkstyle, SpotBugs, PMD, and google-java-format
set -euo pipefail

FAIL_ON="${FAIL_ON:-warning}"
TARGET="${1:-.}"
EXIT_CODE=0

log() { echo "[iDevOps] $*"; }
warn() { log "WARN: $*"; }
ok() { log "OK: $*"; }

check_exit() {
  local code=$1 tool=$2
  case "$FAIL_ON" in
    error)   [[ $code -gt 1 ]] && EXIT_CODE=1 ;;
    warning) [[ $code -gt 0 ]] && EXIT_CODE=1 ;;
    info)    [[ $code -ne 0 ]] && EXIT_CODE=1 ;;
    none)    ;;
  esac
  if [[ $code -eq 0 ]]; then ok "$tool passed"; else warn "$tool found issues (exit $code)"; fi
}

has_java() { find "$TARGET" -maxdepth 3 -name "*.java" -type f 2>/dev/null | head -1 | grep -q .; }

if ! has_java; then
  warn "No Java files found. Skipping."
  exit 0
fi

# --- Checkstyle ---
log "--- Checkstyle ---"
if [[ -f "pom.xml" ]] && command -v mvn &>/dev/null; then
  mvn checkstyle:check -q 2>&1
  check_exit $? "Checkstyle"
elif [[ -f "build.gradle" ]] && command -v gradle &>/dev/null; then
  gradle checkstyleMain 2>&1
  check_exit $? "Checkstyle"
else
  if ! command -v checkstyle &>/dev/null; then
    log "Installing checkstyle..."
    CHECKSTYLE_VERSION="10.12.5"
    CHECKSTYLE_JAR="checkstyle-${CHECKSTYLE_VERSION}-all.jar"
    curl -sL -o /tmp/checkstyle.jar "https://github.com/checkstyle/checkstyle/releases/download/checkstyle-${CHECKSTYLE_VERSION}/${CHECKSTYLE_JAR}" 2>/dev/null || true
  fi
  if [[ -f /tmp/checkstyle.jar ]]; then
    java -jar /tmp/checkstyle.jar "$TARGET" 2>&1
    check_exit $? "Checkstyle"
  else
    warn "Checkstyle installation failed. Skipping."
  fi
fi

# --- SpotBugs ---
log "--- SpotBugs ---"
if [[ -f "pom.xml" ]] && command -v mvn &>/dev/null; then
  mvn spotbugs:check -q 2>&1
  check_exit $? "SpotBugs"
else
  warn "No Maven build. Skipping SpotBugs."
fi

# --- PMD ---
log "--- PMD ---"
if ! command -v pmd &>/dev/null; then
  log "Installing PMD..."
  PMD_VERSION="7.0.0"
  curl -sL "https://github.com/pmd/pmd/releases/download/pmd_releases%2F${PMD_VERSION}/pmd-dist-${PMD_VERSION}-bin.zip" -o /tmp/pmd.zip 2>/dev/null || true
  unzip -qo /tmp/pmd.zip -d /opt/pmd 2>/dev/null || true
fi
if [[ -d /opt/pmd/pmd-bin-* ]]; then
  PMD_DIR=$(ls -d /opt/pmd/pmd-bin-* 2>/dev/null | head -1)
  "$PMD_DIR/bin/pmd" check -d "$TARGET" -R rulesets/java/quickstart.xml -f text 2>&1
  check_exit $? "PMD"
else
  warn "PMD installation failed. Skipping."
fi

# --- google-java-format ---
log "--- google-java-format ---"
if ! command -v google-java-format &>/dev/null; then
  GJF_VERSION="1.19.1"
  curl -sL -o /tmp/google-java-format.jar \
    "https://github.com/google/google-java-format/releases/download/v${GJF_VERSION}/google-java-format-${GJF_VERSION}-all-deps.jar" 2>/dev/null || true
fi
if [[ -f /tmp/google-java-format.jar ]]; then
  find "$TARGET" -name "*.java" -exec java -jar /tmp/google-java-format.jar --dry-run --set-exit-if-changed {} + 2>&1
  check_exit $? "google-java-format"
else
  warn "google-java-format installation failed. Skipping."
fi

log "=== Java lint complete ==="
exit $EXIT_CODE
