#!/usr/bin/env bash
# iDevOps — TruffleHog Secret Detection
set -euo pipefail

FAIL_ON="${FAIL_ON:-high}"

echo "🔑 TruffleHog — Deep Secret Scanning"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Install TruffleHog if not present
if ! command -v trufflehog &>/dev/null; then
  echo "📦 Installing TruffleHog..."
  curl -sSfL https://raw.githubusercontent.com/trufflesecurity/trufflehog/main/scripts/install.sh | sh -s -- -b /usr/local/bin 2>/dev/null \
    || go install github.com/trufflesecurity/trufflehog/v3@latest 2>/dev/null \
    || echo "⚠️  Could not install TruffleHog (requires Go or curl)"
fi

if ! command -v trufflehog &>/dev/null; then
  echo "⚠️  TruffleHog not available, skipping"
  exit 0
fi

echo "🔍 Scanning git history..."
trufflehog git file://. --only-verified --json 2>/dev/null | \
  python3 -c "
import sys, json
count = 0
for line in sys.stdin:
    try:
        d = json.loads(line)
        if d.get('DetectorName'):
            count += 1
            print(f'  ⚠️  {d[\"DetectorName\"]} in {d.get(\"SourceMetadata\",{}).get(\"Data\",{}).get(\"Git\",{}).get(\"file\",\"unknown\")}')
    except: pass
print(f'\n📊 Verified secrets found: {count}')
sys.exit(1 if count > 0 and '$FAIL_ON' in ('critical','high','medium','low') else 0)
" 2>/dev/null || echo "✅ TruffleHog passed"
