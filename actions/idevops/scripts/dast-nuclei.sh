#!/usr/bin/env bash
set -euo pipefail

echo "[iDevOps] DAST Scan - Nuclei"
echo "[iDevOps] ======================"

TARGET_URL="${IDEVOPS_TARGET_URL:-}"
REPORT_DIR="${IDEVOPS_REPORT_DIR:-/tmp/idevops/reports}"
SEVERITY="${IDEVOPS_DAST_SEVERITY:-critical,high}"
TEMPLATES="${IDEVOPS_DAST_TEMPLATES:-}"

mkdir -p "$REPORT_DIR"

echo "[iDevOps] ::group::Configuration"
echo "[iDevOps] Target URL: ${TARGET_URL:-<not set>}"
echo "[iDevOps] Severity: $SEVERITY"
echo "[iDevOps] Templates: ${TEMPLATES:-<all>}"
echo "[iDevOps] Report Dir: $REPORT_DIR"
echo "[iDevOps] ::endgroup::"

if [ -z "$TARGET_URL" ]; then
    echo "[iDevOps] WARNING: IDEVOPS_TARGET_URL is not set or empty."
    echo "[iDevOps] Skipping DAST scan. Set IDEVOPS_TARGET_URL to enable."
    echo "[iDevOps] Exit 0 (skip)."
    exit 0
fi

echo "[iDevOps] ::group::Install Nuclei"
if command -v nuclei &>/dev/null; then
    echo "[iDevOps] Nuclei is already installed: $(nuclei -version 2>&1 || true)"
else
    echo "[iDevOps] Nuclei not found. Installing..."
    if command -v go &>/dev/null; then
        echo "[iDevOps] Installing via go install..."
        go install -v github.com/projectdiscovery/nuclei/v3/cmd/nuclei@latest
    else
        echo "[iDevOps] Go not found. Downloading pre-built binary..."
        NUCLEI_VERSION=$(curl -s https://api.github.com/repos/projectdiscovery/nuclei/releases/latest | grep '"tag_name"' | head -1 | sed 's/.*"tag_name":\s*"\([^"]*\)".*/\1/' || true)
        if [ -z "$NUCLEI_VERSION" ]; then
            NUCLEI_VERSION="v3.3.7"
        fi
        ARCH=$(uname -m)
        case "$ARCH" in
            x86_64) ARCH="amd64" ;;
            aarch64) ARCH="arm64" ;;
            armv7l) ARCH="armv6" ;;
        esac
        OS=$(uname -s | tr '[:upper:]' '[:lower:]')
        DOWNLOAD_URL="https://github.com/projectdiscovery/nuclei/releases/download/${NUCLEI_VERSION}/nuclei_${NUCLEI_VERSION}_${OS}_${ARCH}.zip"
        echo "[iDevOps] Downloading nuclei ${NUCLEI_VERSION} for ${OS}/${ARCH}..."
        TMP_DIR=$(mktemp -d)
        curl -sL "$DOWNLOAD_URL" -o "${TMP_DIR}/nuclei.zip"
        unzip -o "${TMP_DIR}/nuclei.zip" -d "${TMP_DIR}"
        chmod +x "${TMP_DIR}/nuclei"
        mkdir -p "${HOME}/.local/bin"
        mv "${TMP_DIR}/nuclei" "${HOME}/.local/bin/nuclei"
        export PATH="${HOME}/.local/bin:$PATH"
        rm -rf "$TMP_DIR"
        echo "[iDevOps] Nuclei installed to ${HOME}/.local/bin/nuclei"
    fi
fi
echo "[iDevOps] ::endgroup::"

if ! command -v nuclei &>/dev/null; then
    echo "[iDevOps] ERROR: Failed to install Nuclei."
    echo "[iDevOps] Exit 0 (skip)."
    exit 0
fi

echo "[iDevOps] ::group::Update Nuclei Templates"
nuclei -update-templates -silent 2>&1 || echo "[iDevOps] WARNING: Template update failed, continuing with existing templates."
echo "[iDevOps] ::endgroup::"

SARIF_FILE="${REPORT_DIR}/dast-nuclei.sarif"
TEXT_FILE="${REPORT_DIR}/dast-nuclei.txt"

NUCLEI_ARGS=(
    -u "$TARGET_URL"
    -severity "$SEVERITY"
    -silent
    -nc
    -timeout 10
    -retries 1
    -rate-limit 50
)

if [ -n "$TEMPLATES" ]; then
    NUCLEI_ARGS+=(-t "$TEMPLATES")
fi

echo "[iDevOps] ::group::Scan $TARGET_URL"
echo "[iDevOps] Running: nuclei ${NUCLEI_ARGS[*]}"

SCAN_EXIT=0
nuclei "${NUCLEI_ARGS[@]}" -json -o "$TEXT_FILE" 2>/dev/null >> "$TEXT_FILE.raw" || SCAN_EXIT=$?

if [ "$SCAN_EXIT" -ne 0 ] && [ "$SCAN_EXIT" -ne 1 ]; then
    echo "[iDevOps] Nuclei exited with code $SCAN_EXIT."
fi

echo "[iDevOps] ::endgroup::"

echo "[iDevOps] ::group::Process Results"

if [ -f "$TEXT_FILE.raw" ] && [ -s "$TEXT_FILE.raw" ]; then
    FINDING_COUNT=$(wc -l < "$TEXT_FILE.raw")
    echo "[iDevOps] Findings: $FINDING_COUNT"
    mv "$TEXT_FILE.raw" "$TEXT_FILE"
else
    echo "[iDevOps] No findings."
    echo "[]"> "$TEXT_FILE"
    rm -f "$TEXT_FILE.raw"
fi

echo "[iDevOps] ::endgroup::"

echo "[iDevOps] ::group::Generate SARIF"

if command -v nuclei &>/dev/null; then
    NUCLEI_SARIF_ARGS=(
        -u "$TARGET_URL"
        -severity "$SEVERITY"
        -silent
        -nc
        -timeout 10
        -retries 1
        -sarif-output "$SARIF_FILE"
    )
    if [ -n "$TEMPLATES" ]; then
        NUCLEI_SARIF_ARGS+=(-t "$TEMPLATES")
    fi
    nuclei "${NUCLEI_SARIF_ARGS[@]}" > /dev/null 2>&1 || true
fi

if [ -f "$SARIF_FILE" ] && [ -s "$SARIF_FILE" ]; then
    echo "[iDevOps] SARIF report saved: $SARIF_FILE"
else
    echo "[iDevOps] SARIF not available. Using text output."
    rm -f "$SARIF_FILE"
fi
echo "[iDevOps] ::endgroup::"

echo "[iDevOps] ======================"
echo "[iDevOps] DAST scan completed."
echo "[iDevOps] Text report: $TEXT_FILE"
[ -f "$SARIF_FILE" ] && echo "[iDevOps] SARIF report: $SARIF_FILE"
echo "[iDevOps] Exit 0 (continue-on-error friendly)."
exit 0
