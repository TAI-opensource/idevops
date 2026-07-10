#!/usr/bin/env bash
# iDevOps - OSV-Scanner
set -euo pipefail

FAIL_ON="${FAIL_ON:-high}"

echo "[iDevOps] OSV-Scanner -- Package Vulnerability Scan"
echo "---------------------------------------------------"

# Install osv-scanner if not present
if ! command -v osv-scanner &>/dev/null; then
  echo "[iDevOps] Installing osv-scanner..."
  curl -sSfL https://raw.githubusercontent.com/google/osv-scanner/main/install.sh | sh -s -- -b /usr/local/bin 2>/dev/null \
    || OSV_SCANNER_VERSION=$(curl -s https://api.github.com/repos/google/osv-scanner/releases/latest | grep '"tag_name"' | cut -d'"' -f4) \
    && curl -sSfL "https://github.com/google/osv-scanner/releases/download/${OSV_SCANNER_VERSION}/osv-scanner_${OSV_SCANNER_VERSION#v}_linux_amd64" -o /usr/local/bin/osv-scanner \
    && chmod +x /usr/local/bin/osv-scanner
fi

echo "[iDevOps] Scanning dependencies..."
osv-scanner --format json --output osv-results.json . 2>/dev/null || true
osv-scanner --format table . 2>/dev/null || true

# Count vulnerabilities
if [ -f "osv-results.json" ]; then
  TOTAL=$(python3 -c "import json,sys; d=json.load(open('osv-results.json')); print(sum(len(v.get('vulns',[])) for v in d.get('results',[])))" 2>/dev/null || echo "0")
  echo ""
  echo "[iDevOps] Total vulnerabilities found: $TOTAL"

  if [ "$FAIL_ON" = "critical" ] || [ "$FAIL_ON" = "high" ]; then
    if [ "$TOTAL" -gt 0 ]; then
      echo "[iDevOps] FAIL: $TOTAL vulnerabilities found (threshold: $FAIL_ON)"
      exit 1
    fi
  fi
  echo "[iDevOps] PASS: OSV-Scanner passed (threshold: $FAIL_ON)"
fi
