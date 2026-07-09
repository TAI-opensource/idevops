#!/usr/bin/env bash
# iDevOps — Python Linting (Ruff)
set -euo pipefail

FAIL_ON="${FAIL_ON:-high}"
FIX="${FIX:-false}"

echo "🧹 Ruff — Python Linting & Formatting"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

EXIT_CODE=0

# Install Ruff if not present
if ! command -v ruff &>/dev/null; then
  echo "📦 Installing Ruff..."
  curl -sSfL https://github.com/astral-sh/ruff/releases/latest/download/ruff-x86_64-unknown-linux-gnu.tar.gz | tar xz -C /usr/local/bin ruff 2>/dev/null \
    || pip3 install ruff 2>/dev/null \
    || pip install ruff 2>/dev/null
fi

if command -v ruff &>/dev/null; then
  echo "🔍 Running Ruff linter..."
  RUFF_ARGS="check --output-format sarif"
  if [ "$FIX" = "true" ]; then
    RUFF_ARGS="$RUFF_ARGS --fix"
  fi
  ruff $RUFF_ARGS . > ruff-lint.sarif 2>/dev/null || EXIT_CODE=$?

  echo "🔍 Running Ruff formatter check..."
  ruff format --check . 2>/dev/null || echo "  ⚠️  Formatting issues found (run 'ruff format .' to fix)"

  # Count findings
  FINDINGS=0
  if [ -f "ruff-lint.sarif" ]; then
    FINDINGS=$(grep -c '"ruleId"' "ruff-lint.sarif" 2>/dev/null || echo "0")
  fi

  echo ""
  echo "📊 Ruff findings: $FINDINGS"

  if [ "$EXIT_CODE" -ne 0 ]; then
    if [ "$FAIL_ON" = "critical" ] || [ "$FAIL_ON" = "high" ]; then
      echo "❌ Failing: lint errors found (threshold: $FAIL_ON)"
      exit 1
    fi
  fi
  echo "✅ Ruff passed (threshold: $FAIL_ON)"
else
  echo "⚠️  Ruff not available, skipping"
fi
