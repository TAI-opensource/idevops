#!/usr/bin/env bash
# iDevOps - Gitleaks Secret Detection
set -euo pipefail

FAIL_ON="${FAIL_ON:-high}"

echo "[iDevOps] Gitleaks -- Secret Detection"
echo "--------------------------------------"

# Install Gitleaks if not present
if ! command -v gitleaks &>/dev/null; then
  echo "[iDevOps] Installing Gitleaks..."
  GITLEAKS_VERSION=$(curl -s https://api.github.com/repos/gitleaks/gitleaks/releases/latest | grep '"tag_name"' | cut -d'"' -f4)
  curl -sSfL "https://github.com/gitleaks/gitleaks/releases/download/${GITLEAKS_VERSION}/gitleaks_${GITLEAKS_VERSION#v}_linux_x64.tar.gz" | tar xz -C /usr/local/bin gitleaks
fi

echo "[iDevOps] Scanning git history for secrets..."
gitleaks detect \
  --source . \
  --report-format sarif \
  --report-path gitleaks-results.sarif \
  --redact \
  --verbose 2>&1 || EXIT_CODE=$?

EXIT_CODE=${EXIT_CODE:-0}

# Count findings
FINDINGS=0
if [ -f "gitleaks-results.sarif" ]; then
  FINDINGS=$(grep -c '"ruleId"' "gitleaks-results.sarif" 2>/dev/null || echo "0")
fi

echo ""
echo "[iDevOps] Secrets found: $FINDINGS"

if [ "$EXIT_CODE" -eq 1 ]; then
  if [ "$FAIL_ON" = "critical" ] || [ "$FAIL_ON" = "high" ] || [ "$FAIL_ON" = "medium" ]; then
    echo "[iDevOps] FAIL: secrets detected (threshold: $FAIL_ON)"
    exit 1
  fi
fi
echo "[iDevOps] PASS: Gitleaks passed (threshold: $FAIL_ON)"
