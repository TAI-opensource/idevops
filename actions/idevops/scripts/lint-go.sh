#!/usr/bin/env bash
# iDevOps - Go Linting (go vet + staticcheck)
set -euo pipefail

FAIL_ON="${FAIL_ON:-high}"

echo "[iDevOps] Go Vet & staticcheck -- Go Linting"
echo "---------------------------------------------"

EXIT_CODE=0

if [ -f "go.mod" ]; then
  echo "[iDevOps] Running go vet..."
  go vet ./... 2>&1 || EXIT_CODE=$?

  echo "[iDevOps] Running staticcheck..."
  if ! command -v staticcheck &>/dev/null; then
    go install honnef.co/go/tools/cmd/staticcheck@latest 2>/dev/null || true
  fi
  if command -v staticcheck &>/dev/null; then
    staticcheck ./... 2>&1 || EXIT_CODE=$?
  fi

  echo "[iDevOps] Running gofmt check..."
  GOFMT_DIFF=$(gofmt -l . 2>/dev/null)
  if [ -n "$GOFMT_DIFF" ]; then
    echo "  WARNING: Files need formatting:"
    echo "$GOFMT_DIFF" | sed 's/^/    /'
  fi

  echo ""
  if [ "$EXIT_CODE" -ne 0 ]; then
    if [ "$FAIL_ON" = "critical" ] || [ "$FAIL_ON" = "high" ]; then
      echo "[iDevOps] FAIL: Go lint errors found (threshold: $FAIL_ON)"
      exit 1
    fi
  fi
  echo "[iDevOps] PASS: Go linting passed (threshold: $FAIL_ON)"
else
  echo "[iDevOps] No go.mod found, skipping"
fi
