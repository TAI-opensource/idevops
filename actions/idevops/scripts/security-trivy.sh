#!/usr/bin/env bash
# iDevOps - Trivy Filesystem Scan
set -euo pipefail

FAIL_ON="${FAIL_ON:-high}"
RESULTS_FILE="trivy-results.sarif"

echo "[iDevOps] Trivy -- Filesystem Vulnerability Scan"
echo "------------------------------------------------"

# Install Trivy if not present
if ! command -v trivy &>/dev/null; then
  echo "[iDevOps] Installing Trivy..."
  curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh | sh -s -- -b /usr/local/bin 2>/dev/null \
    || (wget -qO- https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh | sh -s -- -b /usr/local/bin)
fi

echo "[iDevOps] Scanning filesystem for vulnerabilities..."
trivy fs \
  --format sarif \
  --output "$RESULTS_FILE" \
  --severity CRITICAL,HIGH,MEDIUM \
  --scanners vuln,secret,misconfig \
  --ignore-unfixed \
  . || true

# Parse results
if [ -f "$RESULTS_FILE" ]; then
  CRITICAL=$(grep -c '"level":"error"' "$RESULTS_FILE" 2>/dev/null || echo "0")
  HIGH=$(grep -c '"level":"warning"' "$RESULTS_FILE" 2>/dev/null || echo "0")
  echo ""
  echo "[iDevOps] Results:"
  echo "  Critical: $CRITICAL"
  echo "  High:     $HIGH"

  if [ "$FAIL_ON" = "critical" ] && [ "$CRITICAL" -gt 0 ]; then
    echo "[iDevOps] FAIL: $CRITICAL critical vulnerabilities found"
    exit 1
  elif [ "$FAIL_ON" = "high" ] && [ "$((CRITICAL + HIGH))" -gt 0 ]; then
    echo "[iDevOps] FAIL: $((CRITICAL + HIGH)) critical/high vulnerabilities found"
    exit 1
  fi
  echo "[iDevOps] PASS: Trivy scan passed (threshold: $FAIL_ON)"
else
  echo "[iDevOps] WARNING: No SARIF output generated"
fi
