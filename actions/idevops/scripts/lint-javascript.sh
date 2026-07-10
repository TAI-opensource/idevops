#!/usr/bin/env bash
# [iDevOps] Lint script for JavaScript/TypeScript using ESLint, Biome, and Prettier
set -euo pipefail

FAIL_ON="${FAIL_ON:-warning}"
TARGET="${1:-.}"
EXIT_CODE=0

log() { echo "[iDevOps] $*"; }
warn() { log "WARN: $*"; }
err() { log "ERROR: $*"; }
ok() { log "OK: $*"; }

check_exit() {
  local code=$1 severity=$2 tool=$3
  case "$FAIL_ON" in
    error)   [[ $code -gt 1 ]] && EXIT_CODE=1 ;;
    warning) [[ $code -gt 0 ]] && EXIT_CODE=1 ;;
    info)    [[ $code -ne 0 ]] && EXIT_CODE=1 ;;
    none)    ;;
  esac
  if [[ $code -eq 0 ]]; then ok "$tool passed"; else warn "$tool found issues (exit $code)"; fi
}

install_tool() {
  local cmd=$1 pkg=$2
  if ! command -v "$cmd" &>/dev/null; then
    log "Installing $pkg..."
    if command -v npm &>/dev/null; then npm install -g "$pkg" 2>/dev/null || pip install "$pkg" 2>/dev/null; fi
  fi
}

has_files() { find "$TARGET" -maxdepth 3 -type f -name "$1" 2>/dev/null | head -1 | grep -q .; }

has_ext() { find "$TARGET" -maxdepth 3 -type f \( -name "*.$1" -o -name "*.$2" -o -name "*.$3" \) 2>/dev/null | head -1 | grep -q .; }

# --- ESLint ---
if has_ext "js" "ts" "mjs" "cjs"; then
  log "--- ESLint ---"
  if ! command -v eslint &>/dev/null; then
    if command -v npx &>/dev/null; then
      log "Using npx for eslint..."
    else
      install_tool npm npm
    fi
  fi
  if [[ -f "eslint.config.js" ]] || [[ -f "eslint.config.mjs" ]] || [[ -f "eslint.config.cjs" ]] || [[ -f ".eslintrc.js" ]] || [[ -f ".eslintrc.json" ]] || [[ -f ".eslintrc.yml" ]] || [[ -f ".eslintrc" ]]; then
    ESLINT_CMD="npx eslint"
    if command -v eslint &>/dev/null; then ESLINT_CMD="eslint"; fi
    if $ESLINT_CMD --format json "$TARGET" > /tmp/eslint-results.json 2>/tmp/eslint-errors.txt; then
      check_exit 0 "error" "ESLint"
    else
      CODE=$?
      check_exit $CODE "error" "ESLint"
      if [[ -f /tmp/eslint-results.json ]]; then cat /tmp/eslint-results.json; fi
    fi
  else
    warn "No ESLint config found. Skipping ESLint."
  fi
fi

# --- Biome ---
if has_ext "js" "ts" "jsx" "tsx"; then
  log "--- Biome ---"
  if ! command -v biome &>/dev/null; then
    if command -v npx &>/dev/null; then
      log "Using npx for biome..."
    fi
  fi
  if [[ -f "biome.json" ]] || [[ -f "biome.jsonc" ]]; then
    BIOME_CMD="npx @biomejs/biome"
    if command -v biome &>/dev/null; then BIOME_CMD="biome"; fi
    if $BIOME_CMD lint "$TARGET" 2>&1; then
      check_exit 0 "error" "Biome"
    else
      CODE=$?
      check_exit $CODE "error" "Biome"
    fi
  else
    warn "No biome.json found. Skipping Biome."
  fi
fi

# --- Prettier ---
if has_ext "js" "ts" "jsx" "tsx" "mjs" "cjs"; then
  log "--- Prettier ---"
  if ! command -v prettier &>/dev/null; then
    if command -v npx &>/dev/null; then
      log "Using npx for prettier..."
    fi
  fi
  if [[ -f ".prettierrc" ]] || [[ -f ".prettierrc.json" ]] || [[ -f ".prettierrc.js" ]] || [[ -f ".prettierrc.yml" ]] || [[ -f "prettier.config.js" ]]; then
    PRETTIER_CMD="npx prettier"
    if command -v prettier &>/dev/null; then PRETTIER_CMD="prettier"; fi
    if $PRETTIER_CMD --check "$TARGET" 2>&1; then
      check_exit 0 "error" "Prettier"
    else
      CODE=$?
      check_exit $CODE "error" "Prettier"
    fi
  else
    warn "No .prettierrc found. Skipping Prettier."
  fi
fi

log "=== JavaScript/TypeScript lint complete ==="
exit $EXIT_CODE
