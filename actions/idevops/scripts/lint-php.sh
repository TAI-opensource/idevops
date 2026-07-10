#!/usr/bin/env bash
# [iDevOps] Lint script for PHP using PHP_CodeSniffer, PHPStan, Psalm, and PHP-CS-Fixer
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

has_php() { find "$TARGET" -maxdepth 3 -name "*.php" -type f 2>/dev/null | head -1 | grep -q .; }

if ! has_php; then
  warn "No PHP files found. Skipping."
  exit 0
fi

# --- PHP_CodeSniffer ---
log "--- PHP_CodeSniffer ---"
if ! command -v phpcs &>/dev/null; then
  log "Installing PHP_CodeSniffer..."
  if command -v composer &>/dev/null; then composer global require squizlabs/php_codesniffer 2>/dev/null || true; fi
fi
if command -v phpcs &>/dev/null; then
  phpcs --report=json "$TARGET" 2>&1 | tee /tmp/phpcs-results.json
  check_exit ${PIPESTATUS[0]} "PHP_CodeSniffer"
else
  warn "PHP_CodeSniffer installation failed. Skipping."
fi

# --- PHPStan ---
log "--- PHPStan ---"
if ! command -v phpstan &>/dev/null; then
  log "Installing PHPStan..."
  if command -v composer &>/dev/null; then composer global require phpstan/phpstan 2>/dev/null || true; fi
fi
if command -v phpstan &>/dev/null; then
  phpstan analyse --format=json "$TARGET" 2>&1 | tee /tmp/phpstan-results.json
  check_exit ${PIPESTATUS[0]} "PHPStan"
else
  warn "PHPStan installation failed. Skipping."
fi

# --- Psalm ---
log "--- Psalm ---"
if ! command -v psalm &>/dev/null; then
  log "Installing Psalm..."
  if command -v composer &>/dev/null; then composer global require vimeo/psalm 2>/dev/null || true; fi
fi
if command -v psalm &>/dev/null; then
  psalm --output-format=json "$TARGET" 2>&1 | tee /tmp/psalm-results.json
  check_exit ${PIPESTATUS[0]} "Psalm"
else
  warn "Psalm installation failed. Skipping."
fi

# --- PHP-CS-Fixer ---
log "--- PHP-CS-Fixer ---"
if ! command -v php-cs-fixer &>/dev/null && ! command -v php-cs-fixer.phar &>/dev/null; then
  log "Installing PHP-CS-Fixer..."
  curl -L https://github.com/PHP-CS-Fixer/PHP-CS-Fixer/releases/latest/download/php-cs-fixer.phar -o /tmp/php-cs-fixer.phar 2>/dev/null || true
  chmod +x /tmp/php-cs-fixer.phar 2>/dev/null || true
  sudo mv /tmp/php-cs-fixer.phar /usr/local/bin/php-cs-fixer 2>/dev/null || true
fi
if command -v php-cs-fixer &>/dev/null; then
  php-cs-fixer fix --dry-run --diff --format=json "$TARGET" 2>&1 | tee /tmp/php-cs-fixer-results.json
  check_exit ${PIPESTATUS[0]} "PHP-CS-Fixer"
else
  warn "PHP-CS-Fixer installation failed. Skipping."
fi

log "=== PHP lint complete ==="
exit $EXIT_CODE
