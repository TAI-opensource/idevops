#!/usr/bin/env bash
# [iDevOps] Lint script for Python using Ruff, Pylint, Mypy, Bandit, Black, isort
set -euo pipefail

FAIL_ON="${FAIL_ON:-warning}"
TARGET="${1:-.}"
EXIT_CODE=0

log() { echo "[iDevOps] $*"; }
warn() { log "WARN: $*"; }
err() { log "ERROR: $*"; }
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

install_if_missing() {
  local cmd=$1 pkg=$2
  if ! command -v "$cmd" &>/dev/null; then
    log "Installing $pkg..."
    if command -v pipx &>/dev/null; then pipx install "$pkg" 2>/dev/null || pip install --user "$pkg" 2>/dev/null;
    elif command -v pip &>/dev/null; then pip install --user "$pkg" 2>/dev/null; fi
  fi
}

has_py_files() { find "$TARGET" -maxdepth 3 -type f -name "*.py" 2>/dev/null | head -1 | grep -q .; }

if ! has_py_files; then
  warn "No Python files found. Exiting."
  exit 0
fi

# --- Ruff ---
log "--- Ruff ---"
install_if_missing ruff ruff
if [[ -f "pyproject.toml" ]] || [[ -f "ruff.toml" ]]; then
  ruff check "$TARGET" --output-format json 2>&1 | tee /tmp/ruff-results.json
  check_exit ${PIPESTATUS[0]} "Ruff"
else
  ruff check "$TARGET" 2>&1
  check_exit $? "Ruff"
fi

# --- Pylint ---
log "--- Pylint ---"
install_if_missing pylint pylint
if [[ -f ".pylintrc" ]] || [[ -f "pyproject.toml" ]] || [[ -f "setup.cfg" ]]; then
  pylint --output-format=json "$TARGET" 2>&1 | tee /tmp/pylint-results.json
  check_exit ${PIPESTATUS[0]} "Pylint"
else
  pylint "$TARGET" 2>&1
  check_exit $? "Pylint"
fi

# --- Mypy ---
log "--- Mypy ---"
install_if_missing mypy mypy
if [[ -f "mypy.ini" ]] || [[ -f ".mypy.ini" ]] || [[ -f "pyproject.toml" ]]; then
  mypy --output-json "$TARGET" 2>&1 | tee /tmp/mypy-results.json
  check_exit ${PIPESTATUS[0]} "Mypy"
else
  mypy "$TARGET" 2>&1
  check_exit $? "Mypy"
fi

# --- Bandit ---
log "--- Bandit ---"
if ! command -v bandit &>/dev/null; then
  log "Installing bandit..."
  pip install --user bandit 2>/dev/null || true
fi
if command -v bandit &>/dev/null; then
  bandit -r "$TARGET" -f json -o /tmp/bandit-results.json 2>&1 || true
  bandit -r "$TARGET" 2>&1
  check_exit $? "Bandit"
else
  warn "Bandit installation failed. Skipping."
fi

# --- Black ---
log "--- Black ---"
install_if_missing black black
if [[ -f "pyproject.toml" ]] || [[ -f ".black" ]]; then
  black --check --diff "$TARGET" 2>&1
  check_exit $? "Black"
else
  black --check --diff "$TARGET" 2>&1
  check_exit $? "Black"
fi

# --- isort ---
log "--- isort ---"
install_if_missing isort isort
if [[ -f ".isort.cfg" ]] || [[ -f "pyproject.toml" ]]; then
  isort --check-only --diff "$TARGET" 2>&1
  check_exit $? "isort"
else
  isort --check-only --diff "$TARGET" 2>&1
  check_exit $? "isort"
fi

log "=== Python lint complete ==="
exit $EXIT_CODE
