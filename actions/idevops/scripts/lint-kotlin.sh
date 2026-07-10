#!/usr/bin/env bash
# [iDevOps] Lint script for Kotlin using ktlint, detekt, and ktfmt
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

has_kt() { find "$TARGET" -maxdepth 3 \( -name "*.kt" -o -name "*.kts" \) -type f 2>/dev/null | head -1 | grep -q .; }

if ! has_kt; then
  warn "No Kotlin files found. Skipping."
  exit 0
fi

# --- ktlint ---
log "--- ktlint ---"
if ! command -v ktlint &>/dev/null; then
  log "Installing ktlint..."
  curl -sSLO https://github.com/pinterest/ktlint/releases/latest/download/ktlint && chmod +x ktlint && sudo mv ktlint /usr/local/bin/ 2>/dev/null || true
fi
if command -v ktlint &>/dev/null; then
  ktlint --reporter=json,output=/tmp/ktlint-results.json "$TARGET" 2>&1
  check_exit $? "ktlint"
else
  warn "ktlint installation failed. Skipping."
fi

# --- detekt ---
log "--- detekt ---"
if ! command -v detekt &>/dev/null; then
  log "Installing detekt..."
  if command -v brew &>/dev/null; then
    brew install detekt 2>/dev/null || true
  else
    DETEKT_VERSION="1.23.3"
    curl -sL -o /tmp/detekt.zip "https://github.com/detekt/detekt/releases/download/v${DETEKT_VERSION}/detekt-cli-${DETEKT_VERSION}.zip" 2>/dev/null || true
    unzip -qo /tmp/detekt.zip -d /opt/detekt 2>/dev/null || true
    ln -sf /opt/detekt/detekt-cli-*/bin/detekt-cli /usr/local/bin/detekt 2>/dev/null || true
  fi
fi
if command -v detekt &>/dev/null; then
  detekt --input "$TARGET" --report json:/tmp/detekt-results.json 2>&1
  check_exit $? "detekt"
else
  warn "detekt installation failed. Skipping."
fi

# --- ktfmt ---
log "--- ktfmt ---"
if ! command -v ktfmt &>/dev/null; then
  log "Installing ktfmt..."
  KTFMT_VERSION="0.16"
  curl -sL -o /tmp/ktfmt.jar "https://github.com/google/ktfmt/releases/download/v${KTFMT_VERSION}/ktfmt-${KTFMT_VERSION}-jar-with-dependencies.jar" 2>/dev/null || true
fi
if [[ -f /tmp/ktfmt.jar ]]; then
  find "$TARGET" -name "*.kt" -exec java -jar /tmp/ktfmt.jar --dry-run {} + 2>&1
  check_exit $? "ktfmt"
else
  warn "ktfmt installation failed. Skipping."
fi

log "=== Kotlin lint complete ==="
exit $EXIT_CODE
