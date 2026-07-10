#!/usr/bin/env bash
# iDevOps - Dependency Audit & Outdated Check
set -euo pipefail

FAIL_ON="${FAIL_ON:-high}"
LANGUAGES="${LANGUAGES:-javascript}"

echo "[iDevOps] Dependencies -- Audit & Outdated Check"
echo "-------------------------------------------------"

# npm/yarn/pnpm
if echo "$LANGUAGES" | grep -qi "javascript\|typescript"; then
  if [ -f "package-lock.json" ] || [ -f "yarn.lock" ] || [ -f "pnpm-lock.yaml" ]; then
    echo "[iDevOps] npm audit..."
    npm audit --audit-level=high 2>/dev/null || echo "  WARNING: Vulnerabilities found in npm dependencies"

    echo ""
    echo "[iDevOps] Outdated packages..."
    npm outdated 2>/dev/null || echo "  INFO: Some packages are outdated"
  fi
fi

# Python (pip-audit)
if echo "$LANGUAGES" | grep -qi "python"; then
  if [ -f "requirements.txt" ] || [ -f "pyproject.toml" ] || [ -f "Pipfile.lock" ]; then
    echo "[iDevOps] pip-audit..."
    if ! command -v pip-audit &>/dev/null; then
      pip3 install pip-audit 2>/dev/null || pip install pip-audit 2>/dev/null || true
    fi
    if command -v pip-audit &>/dev/null; then
      pip-audit 2>/dev/null || echo "  WARNING: Vulnerabilities found in Python dependencies"
    fi
  fi
fi

# Rust (cargo-audit)
if echo "$LANGUAGES" | grep -qi "rust"; then
  if [ -f "Cargo.lock" ]; then
    echo "[iDevOps] cargo audit..."
    if ! command -v cargo-audit &>/dev/null; then
      cargo install cargo-audit 2>/dev/null || true
    fi
    if command -v cargo-audit &>/dev/null; then
      cargo audit 2>/dev/null || echo "  WARNING: Vulnerabilities found in Rust dependencies"
    fi
  fi
fi

# Go (govulncheck)
if echo "$LANGUAGES" | grep -qi "go"; then
  if [ -f "go.sum" ]; then
    echo "[iDevOps] govulncheck..."
    if ! command -v govulncheck &>/dev/null; then
      go install golang.org/x/vuln/cmd/govulncheck@latest 2>/dev/null || true
    fi
    if command -v govulncheck &>/dev/null; then
      govulncheck ./... 2>/dev/null || echo "  WARNING: Vulnerabilities found in Go dependencies"
    fi
  fi
fi

echo ""
echo "[iDevOps] Dependency audit complete"
