#!/usr/bin/env bash
# iDevOps — Code Quality Metrics
set -euo pipefail

LANGUAGES="${LANGUAGES:-javascript}"

echo "📊 Code Quality — Metrics & Analysis"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# ── File Statistics ──
echo ""
echo "📁 Project Statistics:"

# Count files by language
JS_FILES=$(find . -name "*.js" -o -name "*.jsx" -o -name "*.ts" -o -name "*.tsx" 2>/dev/null | grep -v node_modules | grep -v .next | grep -v dist | wc -l)
PY_FILES=$(find . -name "*.py" 2>/dev/null | grep -v node_modules | grep -v __pycache__ | wc -l)
RS_FILES=$(find . -name "*.rs" 2>/dev/null | grep -v target | wc -l)
GO_FILES=$(find . -name "*.go" 2>/dev/null | grep -v vendor | wc -l)
DOCKER_FILES=$(find . -name "Dockerfile*" 2>/dev/null | wc -l)

echo "  JavaScript/TypeScript: $JS_FILES files"
echo "  Python:               $PY_FILES files"
echo "  Rust:                 $RS_FILES files"
echo "  Go:                   $GO_FILES files"
echo "  Dockerfiles:          $DOCKER_FILES files"

# ── Code Metrics ──
echo ""
echo "📏 Code Metrics:"

# Total lines of code
TOTAL_LINES=$(find . \( -name "*.js" -o -name "*.jsx" -o -name "*.ts" -o -name "*.tsx" -o -name "*.py" -o -name "*.rs" -o -name "*.go" \) \
  ! -path "*/node_modules/*" ! -path "*/.next/*" ! -path "*/dist/*" ! -path "*/target/*" ! -path "*/vendor/*" \
  -exec cat {} + 2>/dev/null | wc -l)
echo "  Total lines of code: $TOTAL_LINES"

# Average file size
AVG_SIZE=$(find . \( -name "*.js" -o -name "*.ts" -o -name "*.py" -o -name "*.rs" -o -name "*.go" \) \
  ! -path "*/node_modules/*" ! -path "*/.next/*" ! -path "*/dist/*" ! -path "*/target/*" ! -path "*/vendor/*" \
  -exec stat --format="%s" {} + 2>/dev/null | awk '{sum+=$1; n++} END {if(n>0) printf "%.1f", sum/n/1024; else print "0"}')
echo "  Average file size: ${AVG_SIZE}KB"

# Large files (>500 lines)
LARGE_FILES=$(find . \( -name "*.js" -o -name "*.ts" -o -name "*.py" -o -name "*.rs" -o -name "*.go" \) \
  ! -path "*/node_modules/*" ! -path "*/.next/*" ! -path "*/dist/*" ! -path "*/target/*" ! -path "*/vendor/*" \
  -exec sh -c 'lines=$(wc -l < "$1"); if [ "$lines" -gt 500 ]; then echo "  ⚠️  $1 ($lines lines)"; fi' _ {} \; 2>/dev/null)

if [ -n "$LARGE_FILES" ]; then
  echo ""
  echo "  Large files (>500 lines):"
  echo "$LARGE_FILES"
else
  echo "  ✅ No large files (>500 lines)"
fi

# ── Documentation ──
echo ""
echo "📝 Documentation:"
README_EXISTS="false"
for f in README.md README.rst README.txt README; do
  if [ -f "$f" ]; then
    README_EXISTS="true"
    break
  fi
done
LICENSE_EXISTS="false"
for f in LICENSE LICENSE.md LICENSE.txt LICENCE; do
  if [ -f "$f" ]; then
    LICENSE_EXISTS="true"
    break
  fi
done
CONTRIBUTING_EXISTS="false"
for f in CONTRIBUTING.md CONTRIBUTING; do
  if [ -f "$f" ]; then
    CONTRIBUTING_EXISTS="true"
    break
  fi
done

echo "  README:     $([ "$README_EXISTS" = "true" ] && echo "✅" || echo "❌ missing")"
echo "  LICENSE:    $([ "$LICENSE_EXISTS" = "true" ] && echo "✅" || echo "❌ missing")"
echo "  CONTRIBUTING: $([ "$CONTRIBUTING_EXISTS" = "true" ] && echo "✅" || echo "⚠️  missing")"

# ── CI/CD ──
echo ""
echo "⚙️  CI/CD:"
CI_EXISTS="false"
for f in .github/workflows/*.yml .github/workflows/*.yaml; do
  if [ -f "$f" ]; then
    CI_EXISTS="true"
    break
  fi
done
echo "  GitHub Actions: $([ "$CI_EXISTS" = "true" ] && echo "✅" || echo "❌ missing")"

# ── Score Calculation ──
SCORE=100
[ "$README_EXISTS" = "false" ] && SCORE=$((SCORE - 10))
[ "$LICENSE_EXISTS" = "false" ] && SCORE=$((SCORE - 15))
[ "$CONTRIBUTING_EXISTS" = "false" ] && SCORE=$((SCORE - 5))
[ "$CI_EXISTS" = "false" ] && SCORE=$((SCORE - 10))
[ "$TOTAL_LINES" -gt 50000 ] && SCORE=$((SCORE - 5))
[ -n "$LARGE_FILES" ] && SCORE=$((SCORE - 5))

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🏆 Quality Score: $SCORE/100"
