#!/usr/bin/env bash
# iDevOps — Final Summary Report
set -euo pipefail

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  📋 iDevOps — Final Report"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Count SARIF results
TOTAL_FINDINGS=0
CRITICAL=0
HIGH=0
MEDIUM=0
LOW=0

for sarif in *-results.sarif *-lint.sarif semgrep*.sarif gitleaks-results.sarif hadolint-*.sarif eslint-results.sarif ruff-lint.sarif; do
  [ -f "$sarif" ] || continue
  TOOL=$(basename "$sarif" .sarif)

  # Count by severity
  S_CRITICAL=$(grep -c '"level":"error"' "$sarif" 2>/dev/null || echo "0")
  S_HIGH=$(grep -c '"level":"warning"' "$sarif" 2>/dev/null || echo "0")
  S_MEDIUM=$(grep -c '"level":"note"' "$sarif" 2>/dev/null || echo "0")

  TOOL_TOTAL=$((S_CRITICAL + S_HIGH + S_MEDIUM))
  TOTAL_FINDINGS=$((TOTAL_FINDINGS + TOOL_TOTAL))
  CRITICAL=$((CRITICAL + S_CRITICAL))
  HIGH=$((HIGH + S_HIGH))
  MEDIUM=$((MEDIUM + S_MEDIUM))

  if [ "$TOOL_TOTAL" -gt 0 ]; then
    echo "  🔍 $TOOL: $TOOL_TOTAL findings (C:$S_CRITICAL H:$S_HIGH M:$S_MEDIUM)"
  fi
done

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  📊 Summary"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "  Total findings: $TOTAL_FINDINGS"
echo "  Critical:       $CRITICAL"
echo "  High:           $HIGH"
echo "  Medium:         $MEDIUM"
echo "  Low:            $LOW"
echo ""

# Calculate score
SCORE=100
SCORE=$((SCORE - CRITICAL * 10))
SCORE=$((SCORE - HIGH * 3))
SCORE=$((SCORE - MEDIUM * 1))
[ "$SCORE" -lt 0 ] && SCORE=0

echo "  🏆 Health Score: $SCORE/100"
echo ""

# List SARIF files for upload
SARIF_FILES=""
for f in *-results.sarif *-lint.sarif semgrep*.sarif gitleaks-results.sarif hadolint-*.sarif eslint-results.sarif ruff-lint.sarif; do
  [ -f "$f" ] || continue
  if [ -z "$SARIF_FILES" ]; then
    SARIF_FILES="$f"
  else
    SARIF_FILES="$SARIF_FILES,$f"
  fi
done

if [ -n "$SARIF_FILES" ]; then
  echo "  📁 SARIF files: $SARIF_FILES"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Set outputs for GitHub Actions
if [ -n "${GITHUB_OUTPUT:-}" ]; then
  echo "report<<EOF" >> "$GITHUB_OUTPUT"
  echo "## iDevOps Report" >> "$GITHUB_OUTPUT"
  echo "" >> "$GITHUB_OUTPUT"
  echo "- Total findings: $TOTAL_FINDINGS" >> "$GITHUB_OUTPUT"
  echo "- Critical: $CRITICAL" >> "$GITHUB_OUTPUT"
  echo "- High: $HIGH" >> "$GITHUB_OUTPUT"
  echo "- Medium: $MEDIUM" >> "$GITHUB_OUTPUT"
  echo "- Score: $SCORE/100" >> "$GITHUB_OUTPUT"
  echo "EOF" >> "$GITHUB_OUTPUT"
  echo "score=$SCORE" >> "$GITHUB_OUTPUT"
  echo "files=$SARIF_FILES" >> "$GITHUB_OUTPUT"
fi
