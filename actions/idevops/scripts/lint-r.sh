#!/usr/bin/env bash
# [iDevOps] Lint script for R using lintr and styler
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

has_r() { find "$TARGET" -maxdepth 3 -name "*.R" -type f 2>/dev/null | head -1 | grep -q .; }

if ! has_r; then
  warn "No R files found. Skipping."
  exit 0
fi

# --- lintr ---
log "--- lintr ---"
if ! Rscript -e 'library(lintr)' 2>/dev/null; then
  log "Installing lintr..."
  Rscript -e 'install.packages("lintr", repos="https://cloud.r-project.org", quiet=TRUE)' 2>/dev/null || true
fi
if Rscript -e 'library(lintr)' 2>/dev/null; then
  Rscript -e '
    results <- lintr::lint_package("'${TARGET}'")
    json <- jsonlite::toJSON(results, auto_unbox=TRUE)
    cat(json)
  ' 2>&1 | tee /tmp/lintr-results.json
  check_exit ${PIPESTATUS[0]} "lintr"
else
  warn "lintr installation failed. Skipping."
fi

# --- styler ---
log "--- styler ---"
if ! Rscript -e 'library(styler)' 2>/dev/null; then
  log "Installing styler..."
  Rscript -e 'install.packages("styler", repos="https://cloud.r-project.org", quiet=TRUE)' 2>/dev/null || true
fi
if Rscript -e 'library(styler)' 2>/dev/null; then
  Rscript -e '
    changed <- styler::style_dir("'${TARGET}'", dry="on")
    if (any(changed$changed)) { quit(status=1) }
  ' 2>&1
  check_exit $? "styler"
else
  warn "styler installation failed. Skipping."
fi

log "=== R lint complete ==="
exit $EXIT_CODE
