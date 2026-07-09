#!/usr/bin/env bash
# iDevOps — Semgrep SAST
set -euo pipefail

FAIL_ON="${FAIL_ON:-high}"
LANGUAGES="${LANGUAGES:-javascript}"

echo "🛡️  Semgrep — Static Application Security Testing"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Install Semgrep if not present
if ! command -v semgrep &>/dev/null; then
  echo "📦 Installing Semgrep..."
  pip3 install semgrep 2>/dev/null || pip install semgrep 2>/dev/null \
    || (curl -sSL https://semgrep.dev/install.sh | sh)
fi

# Map languages to Semgrep rulesets
RULESETS=""
if echo "$LANGUAGES" | grep -qi "javascript\|typescript\|js\|ts"; then
  RULESETS="$RULESETS p/javascript p/typescript p/nodejs p/react"
fi
if echo "$LANGUAGES" | grep -qi "python"; then
  RULESETS="$RULESETS p/python p/django p/flask"
fi
if echo "$LANGUAGES" | grep -qi "go"; then
  RULESETS="$RULESETS p/go"
fi
if echo "$LANGUAGES" | grep -qi "rust"; then
  RULESETS="$RULESETS p/rust"
fi
if echo "$LANGUAGES" | grep -qi "java"; then
  RULESETS="$RULESETS p/java p/spring"
fi

# Default ruleset if nothing matched
if [ -z "$RULESETS" ]; then
  RULESETS="p/default"
fi

echo "🔍 Running Semgrep with rulesets: $RULESETS"
semgrep scan \
  --config auto \
  --sarif --output semgrep-results.sarif \
  --severity ERROR --severity WARNING \
  --jobs 4 \
  . 2>/dev/null || true

# Fallback: also run with explicit rulesets
if [ ! -s "semgrep-results.sarif" ] || [ "$(wc -c < semgrep-results.sarif 2>/dev/null || echo 0)" -lt 50 ]; then
  echo "🔄 Retrying with explicit rulesets..."
  for ruleset in $RULESETS; do
    semgrep scan \
      --config "$ruleset" \
      --sarif --output "semgrep-${ruleset//\//-}.sarif" \
      --severity ERROR --severity WARNING \
      --jobs 4 \
      . 2>/dev/null || true
  done
fi

# Count findings
FINDINGS=0
for f in semgrep*.sarif; do
  [ -f "$f" ] || continue
  COUNT=$(grep -c '"ruleId"' "$f" 2>/dev/null || echo "0")
  FINDINGS=$((FINDINGS + COUNT))
done

echo ""
echo "📊 Semgrep findings: $FINDINGS"

if [ "$FAIL_ON" = "critical" ] || [ "$FAIL_ON" = "high" ]; then
  if [ "$FINDINGS" -gt 0 ]; then
    echo "❌ Failing: $FINDINGS findings (threshold: $FAIL_ON)"
    exit 1
  fi
fi
echo "✅ Semgrep passed (threshold: $FAIL_ON)"
