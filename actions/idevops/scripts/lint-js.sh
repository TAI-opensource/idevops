#!/usr/bin/env bash
# iDevOps — JavaScript/TypeScript Linting (ESLint + Biome)
set -euo pipefail

FAIL_ON="${FAIL_ON:-high}"
FIX="${FIX:-false}"

echo "🧹 ESLint / Biome — JavaScript & TypeScript Linting"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

EXIT_CODE=0

# Try ESLint first
if [ -f "node_modules/.bin/eslint" ] || command -v eslint &>/dev/null; then
  echo "🔍 Running ESLint..."
  ESLINT_CMD="npx eslint"
  if [ "$FIX" = "true" ]; then
    ESLINT_CMD="$ESLINT_CMD --fix"
  fi
  $ESLINT_CMD . --format sarif --output-file eslint-results.sarif 2>/dev/null || EXIT_CODE=$?
  echo "  ESLint exit code: $EXIT_CODE"
elif [ -f "package.json" ]; then
  echo "📦 Installing ESLint..."
  npm install --no-save eslint @eslint/js typescript-eslint 2>/dev/null && \
    npx eslint . --format sarif --output-file eslint-results.sarif 2>/dev/null || EXIT_CODE=$?
fi

# Try Biome as alternative/extra
if [ -f "biome.json" ] || [ -f "biome.jsonc" ]; then
  echo "🔍 Running Biome..."
  if command -v biome &>/dev/null || [ -f "node_modules/.bin/biome" ]; then
    biome check . --write 2>/dev/null || true
    echo "  Biome check complete"
  fi
fi

# Count findings
FINDINGS=0
if [ -f "eslint-results.sarif" ]; then
  FINDINGS=$(grep -c '"ruleId"' "eslint-results.sarif" 2>/dev/null || echo "0")
fi

echo ""
echo "📊 ESLint findings: $FINDINGS"

if [ "$EXIT_CODE" -ne 0 ]; then
  if [ "$FAIL_ON" = "critical" ] || [ "$FAIL_ON" = "high" ]; then
    echo "❌ Failing: lint errors found (threshold: $FAIL_ON)"
    exit 1
  fi
fi
echo "✅ ESLint passed (threshold: $FAIL_ON)"
