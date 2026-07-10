#!/usr/bin/env bash
# [iDevOps] Lint script for JSON using jsonlint, Prettier, and Biome
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

has_json() { find "$TARGET" -maxdepth 3 -name "*.json" -type f 2>/dev/null | head -1 | grep -q .; }

if ! has_json; then
  warn "No JSON files found. Skipping."
  exit 0
fi

# --- jsonlint ---
log "--- jsonlint ---"
if ! command -v jsonlint &>/dev/null; then
  log "Installing jsonlint..."
  if command -v npm &>/dev/null; then npm install -g jsonlint 2>/dev/null || true; fi
fi
if command -v jsonlint &>/dev/null; then
  find "$TARGET" -maxdepth 3 -name "*.json" -type f -exec jsonlint -q {} + 2>&1
  check_exit $? "jsonlint"
else
  warn "jsonlint installation failed. Skipping."
fi

# --- Prettier (JSON) ---
log "--- Prettier (JSON) ---"
if command -v npx &>/dev/null || command -v prettier &>/dev/null; then
  PRETTIER_CMD="npx prettier"
  if command -v prettier &>/dev/null; then PRETTIER_CMD="prettier"; fi
  if [[ -f ".prettierrc" ]] || [[ -f ".prettierrc.json" ]]; then
    find "$TARGET" -maxdepth 3 -name "*.json" -type f -exec $PRETTIER_CMD --check {} + 2>&1
    check_exit $? "Prettier"
  else
    warn "No .prettierrc found. Skipping Prettier for JSON."
  fi
else
  warn "Prettier not found. Skipping."
fi

# --- Biome (JSON) ---
log "--- Biome (JSON) ---"
if command -v npx &>/dev/null || command -v biome &>/dev/null; then
  BIOME_CMD="biome"
  if ! command -v biome &>/dev/null; then BIOME_CMD="npx @biomejs/biome"; fi
  if [[ -f "biome.json" ]] || [[ -f "biome.jsonc" ]]; then
    $BIOME_CMD check "$TARGET" 2>&1
    check_exit $? "Biome"
  else
    warn "No biome.json found. Skipping Biome for JSON."
  fi
else
  warn "Biome not found. Skipping."
fi

log "=== JSON lint complete ==="
exit $EXIT_CODE
