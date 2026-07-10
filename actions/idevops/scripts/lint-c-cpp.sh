#!/usr/bin/env bash
# [iDevOps] Lint script for C/C++ using cppcheck, clang-tidy, and clang-format
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

has_c() { find "$TARGET" -maxdepth 3 \( -name "*.c" -o -name "*.cpp" -o -name "*.cxx" -o -name "*.cc" -o -name "*.h" -o -name "*.hpp" \) -type f 2>/dev/null | head -1 | grep -q .; }

if ! has_c; then
  warn "No C/C++ files found. Skipping."
  exit 0
fi

# --- cppcheck ---
log "--- cppcheck ---"
if ! command -v cppcheck &>/dev/null; then
  log "Installing cppcheck..."
  if command -v apt-get &>/dev/null; then sudo apt-get install -y cppcheck 2>/dev/null || true;
  elif command -v brew &>/dev/null; then brew install cppcheck 2>/dev/null || true;
  elif command -v dnf &>/dev/null; then sudo dnf install -y cppcheck 2>/dev/null || true; fi
fi
if command -v cppcheck &>/dev/null; then
  cppcheck --enable=all --suppress=missingIncludeSystem --output-file=/tmp/cppcheck-results.json --xml "$TARGET" 2>&1
  cppcheck --enable=all --suppress=missingIncludeSystem "$TARGET" 2>&1
  check_exit $? "cppcheck"
else
  warn "cppcheck installation failed. Skipping."
fi

# --- clang-tidy ---
log "--- clang-tidy ---"
if ! command -v clang-tidy &>/dev/null; then
  log "Installing clang-tidy..."
  if command -v apt-get &>/dev/null; then sudo apt-get install -y clang-tidy 2>/dev/null || true;
  elif command -v brew &>/dev/null; then brew install llvm 2>/dev/null || true; fi
fi
if command -v clang-tidy &>/dev/null; then
  find "$TARGET" -maxdepth 3 \( -name "*.c" -o -name "*.cpp" -o -name "*.cxx" -o -name "*.cc" \) -type f 2>/dev/null | while read -r f; do
    clang-tidy "$f" -- -std=c++17 2>&1
  done
  check_exit $? "clang-tidy"
else
  warn "clang-tidy installation failed. Skipping."
fi

# --- clang-format ---
log "--- clang-format ---"
if ! command -v clang-format &>/dev/null; then
  log "Installing clang-format..."
  if command -v apt-get &>/dev/null; then sudo apt-get install -y clang-format 2>/dev/null || true;
  elif command -v brew &>/dev/null; then brew install llvm 2>/dev/null || true; fi
fi
if command -v clang-format &>/dev/null; then
  find "$TARGET" -maxdepth 3 \( -name "*.c" -o -name "*.cpp" -o -name "*.h" -o -name "*.hpp" \) -type f 2>/dev/null | while read -r f; do
    clang-format --dry-run -Werror "$f" 2>&1
  done
  check_exit $? "clang-format"
else
  warn "clang-format installation failed. Skipping."
fi

log "=== C/C++ lint complete ==="
exit $EXIT_CODE
