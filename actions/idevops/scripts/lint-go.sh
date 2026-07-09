#!/usr/bin/env bash
# iDevOps — Go Linting (go vet + staticcheck)
set -euo pipefail

FAIL_ON="${FAIL_ON:-high}"

echo "🧹 Go Vet & staticcheck — Go Linting"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

EXIT_CODE=0

if [ -f "go.mod" ]; then
  echo "🔍 Running go vet..."
  go vet ./... 2>&1 || EXIT_CODE=$?

  echo "🔍 Running staticcheck..."
  if ! command -v staticcheck &>/dev/null; then
    go install honnef.co/go/tools/cmd/staticcheck@latest 2>/dev/null || true
  fi
  if command -v staticcheck &>/dev/null; then
    staticcheck ./... 2>&1 || EXIT_CODE=$?
  fi

  echo "🔍 Running gofmt check..."
  GOFMT_DIFF=$(gofmt -l . 2>/dev/null)
  if [ -n "$GOFMT_DIFF" ]; then
    echo "  ⚠️  Files need formatting:"
    echo "$GOFMT_DIFF" | sed 's/^/    /'
  fi

  echo ""
  if [ "$EXIT_CODE" -ne 0 ]; then
    if [ "$FAIL_ON" = "critical" ] || [ "$FAIL_ON" = "high" ]; then
      echo "❌ Failing: Go lint errors found (threshold: $FAIL_ON)"
      exit 1
    fi
  fi
  echo "✅ Go linting passed (threshold: $FAIL_ON)"
else
  echo "⚠️  No go.mod found, skipping"
fi
