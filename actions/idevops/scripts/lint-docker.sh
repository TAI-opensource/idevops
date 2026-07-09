#!/usr/bin/env bash
# iDevOps — Dockerfile Linting (Hadolint)
set -euo pipefail

FAIL_ON="${FAIL_ON:-high}"

echo "🧹 Hadolint — Dockerfile Linting"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Find Dockerfiles
DOCKERFILES=$(find . -name "Dockerfile*" -o -name "*.dockerfile" 2>/dev/null | head -20)

if [ -z "$DOCKERFILES" ]; then
  echo "⚠️  No Dockerfiles found, skipping"
  exit 0
fi

# Install Hadolint if not present
if ! command -v hadolint &>/dev/null; then
  echo "📦 Installing Hadolint..."
  curl -sSfL "https://github.com/hadolint/hadolint/releases/download/v2.12.0/hadolint-Linux-x86_64" -o /usr/local/bin/hadolint 2>/dev/null \
    || curl -sSfL "https://github.com/hadolint/hadolint/releases/latest/download/hadolint-Linux-x86_64" -o /usr/local/bin/hadolint
  chmod +x /usr/local/bin/hadolint
fi

EXIT_CODE=0
TOTAL_ISSUES=0

for dockerfile in $DOCKERFILES; do
  echo "🔍 Linting: $dockerfile"
  hadolint "$dockerfile" --format sarif > "hadolint-$(echo "$dockerfile" | tr '/' '-').sarif" 2>/dev/null || EXIT_CODE=$?
  ISSUES=$(grep -c '"ruleId"' "hadolint-$(echo "$dockerfile" | tr '/' '-').sarif" 2>/dev/null || echo "0")
  TOTAL_ISSUES=$((TOTAL_ISSUES + ISSUES))
done

echo ""
echo "📊 Hadolint issues: $TOTAL_ISSUES"

if [ "$EXIT_CODE" -ne 0 ]; then
  if [ "$FAIL_ON" = "critical" ] || [ "$FAIL_ON" = "high" ]; then
    echo "❌ Failing: Dockerfile issues found (threshold: $FAIL_ON)"
    exit 1
  fi
fi
echo "✅ Hadolint passed (threshold: $FAIL_ON)"
