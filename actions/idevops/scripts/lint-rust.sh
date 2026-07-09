#!/usr/bin/env bash
# iDevOps — Rust Linting (Clippy + cargo-audit)
set -euo pipefail

FAIL_ON="${FAIL_ON:-high}"

echo "🧹 Clippy — Rust Linting & Security"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

EXIT_CODE=0

if [ -f "Cargo.toml" ]; then
  echo "🔍 Running Clippy..."
  cargo clippy --all-targets --all-features --message-format json 2>/dev/null | \
    python3 -c "
import sys, json
warnings = 0
errors = 0
for line in sys.stdin:
    try:
        d = json.loads(line)
        msg = d.get('message', {})
        level = msg.get('level', '')
        if level == 'warning': warnings += 1
        elif level == 'error': errors += 1
    except: pass
print(f'  Warnings: {warnings}')
print(f'  Errors:   {errors}')
" 2>/dev/null || EXIT_CODE=$?

  echo "🔍 Running cargo audit..."
  if ! command -v cargo-audit &>/dev/null; then
    cargo install cargo-audit 2>/dev/null || true
  fi
  cargo audit 2>/dev/null || echo "  ⚠️  cargo-audit not available or found issues"

  echo "🔍 Running cargo fmt check..."
  cargo fmt -- --check 2>/dev/null || echo "  ⚠️  Formatting issues (run 'cargo fmt' to fix)"

  echo ""
  if [ "$EXIT_CODE" -ne 0 ]; then
    if [ "$FAIL_ON" = "critical" ] || [ "$FAIL_ON" = "high" ]; then
      echo "❌ Failing: Clippy errors found (threshold: $FAIL_ON)"
      exit 1
    fi
  fi
  echo "✅ Clippy passed (threshold: $FAIL_ON)"
else
  echo "⚠️  No Cargo.toml found, skipping"
fi
