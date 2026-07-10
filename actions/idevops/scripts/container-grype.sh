#!/usr/bin/env bash
set -euo pipefail

echo "[iDevOps] Container Vulnerability Scanner - Grype"
echo "[iDevOps] =========================================="

CONTAINER_IMAGE="${IDEVOPS_CONTAINER_IMAGE:-}"
SEVERITY="${IDEVOPS_GRYPE_SEVERITY:-high,critical}"
REPORT_DIR="${IDEVOPS_REPORT_DIR:-/tmp/idevops/reports}"
DOCKERFILE_PATH="${IDEVOPS_DOCKERFILE_PATH:-}"
SCAN_DIR="${IDEVOPS_SCAN_DIR:-.}"

mkdir -p "$REPORT_DIR"

echo "[iDevOps] ::group::Configuration"
echo "[iDevOps] Container Image: ${CONTAINER_IMAGE:-<not set>}"
echo "[iDevOps] Severity Filter: $SEVERITY"
echo "[iDevOps] Report Dir: $REPORT_DIR"
echo "[iDevOps] Scan Dir: $SCAN_DIR"
echo "[iDevOps] ::endgroup::"

echo "[iDevOps] ::group::Install Grype"
if command -v grype &>/dev/null; then
    echo "[iDevOps] Grype is already installed: $(grype version 2>&1 || true)"
else
    echo "[iDevOps] Grype not found. Installing..."
    curl -sSfL https://raw.githubusercontent.com/anchore/grype/main/install.sh | sh -s -- -b /usr/local/bin 2>/dev/null || {
        echo "[iDevOps] WARNING: Failed to install Grype via official installer."
        echo "[iDevOps] Attempting fallback installation..."
        GRYPE_VERSION=$(curl -s https://api.github.com/repos/anchore/grype/releases/latest | grep '"tag_name"' | head -1 | sed 's/.*"tag_name":\s*"\([^"]*\)".*/\1/' || true)
        if [ -n "$GRYPE_VERSION" ]; then
            ARCH=$(uname -m)
            case "$ARCH" in
                x86_64) ARCH="amd64" ;;
                aarch64) ARCH="arm64" ;;
            esac
            DOWNLOAD_URL="https://github.com/anchore/grype/releases/download/${GRYPE_VERSION}/grype_${GRYPE_VERSION#v}_linux_${ARCH}.tar.gz"
            echo "[iDevOps] Downloading grype ${GRYPE_VERSION} for linux/${ARCH}..."
            TMP_DIR=$(mktemp -d)
            curl -sL "$DOWNLOAD_URL" -o "${TMP_DIR}/grype.tar.gz" && \
                tar xz -C "${TMP_DIR}" grype && \
                chmod +x "${TMP_DIR}/grype" && \
                mv "${TMP_DIR}/grype" /usr/local/bin/grype && \
                echo "[iDevOps] Grype installed to /usr/local/bin/grype" || \
                echo "[iDevOps] WARNING: Failed to install grype via fallback."
            rm -rf "$TMP_DIR"
        else
            echo "[iDevOps] WARNING: Could not determine Grype version."
        fi
    }
fi
echo "[iDevOps] ::endgroup::"

if ! command -v grype &>/dev/null; then
    echo "[iDevOps] ERROR: Grype is not available. Skipping scan."
    echo "[iDevOps] Exit 0 (continue-on-error friendly)."
    exit 0
fi

SARIF_FILE="${REPORT_DIR}/grype-results.sarif"
JSON_FILE="${REPORT_DIR}/grype-results.json"
TABLE_FILE="${REPORT_DIR}/grype-results.txt"

scan_target=""
scan_type=""

if [ -n "$CONTAINER_IMAGE" ]; then
    scan_target="$CONTAINER_IMAGE"
    scan_type="image"
    echo "[iDevOps] ::group::Scan Container Image: $CONTAINER_IMAGE"
elif [ -n "$DOCKERFILE_PATH" ] && [ -f "$DOCKERFILE_PATH" ]; then
    scan_target="$DOCKERFILE_PATH"
    scan_type="dockerfile"
    echo "[iDevOps] ::group::Scan Dockerfile: $DOCKERFILE_PATH"
else
    echo "[iDevOps] ::group::Detect Scan Target"
    found_dockerfile=""
    if [ -f "$SCAN_DIR/Dockerfile" ]; then
        found_dockerfile="$SCAN_DIR/Dockerfile"
    elif [ -f "$SCAN_DIR/dockerfile" ]; then
        found_dockerfile="$SCAN_DIR/dockerfile"
    else
        found_dockerfile=$(find "$SCAN_DIR" -maxdepth 3 \( -name "Dockerfile*" -o -name "*.dockerfile" \) 2>/dev/null | head -1)
    fi

    if [ -n "$found_dockerfile" ]; then
        scan_target="$found_dockerfile"
        scan_type="dockerfile"
        echo "[iDevOps] Found Dockerfile: $found_dockerfile"
    else
        echo "[iDevOps] No container image or Dockerfile found."
        echo "[iDevOps] Set IDEVOPS_CONTAINER_IMAGE or place a Dockerfile to enable scanning."
        echo "[iDevOps] ::endgroup::"
        echo "[iDevOps] Exit 0 (no target)."
        exit 0
    fi
    echo "[iDevOps] ::endgroup::"
fi

if [ "$scan_type" = "image" ]; then
    echo "[iDevOps] ::group::Scanning Image: $scan_target"
    echo "[iDevOps] Running: grype $scan_target --severity $SEVERITY --output sarif --file $SARIF_FILE"

    GRYPE_EXIT=0
    grype "$scan_target" \
        --severity "$SEVERITY" \
        --output sarif \
        --file "$SARIF_FILE" 2>/dev/null || GRYPE_EXIT=$?

    echo "[iDevOps] Grype exit code: $GRYPE_EXIT"
    echo "[iDevOps] ::endgroup::"

    echo "[iDevOps] ::group::Generate JSON Output"
    grype "$scan_target" \
        --severity "$SEVERITY" \
        --output json \
        --file "$JSON_FILE" 2>/dev/null || true
    echo "[iDevOps] ::endgroup::"

    echo "[iDevOps] ::group::Generate Table Output"
    grype "$scan_target" \
        --severity "$SEVERITY" \
        --output table 2>/dev/null | tee "$TABLE_FILE" || true
    echo "[iDevOps] ::endgroup::"
else
    echo "[iDevOps] ::group::Scanning Dockerfile: $scan_target"
    echo "[iDevOps] Note: Grype scans container images. Dockerfile scanning requires building the image first."
    echo "[iDevOps] Attempting to build and scan image from Dockerfile..."

    TEMP_IMAGE="idevops-grype-temp:$(date +%s)"
    BUILD_EXIT=0
    docker build -t "$TEMP_IMAGE" -f "$scan_target" "$(dirname "$scan_target")" 2>/dev/null || BUILD_EXIT=$?

    if [ "$BUILD_EXIT" -eq 0 ] && [ "$(docker images -q "$TEMP_IMAGE" 2>/dev/null | wc -l)" -gt 0 ]; then
        echo "[iDevOps] Image built successfully. Scanning..."
        grype "$TEMP_IMAGE" \
            --severity "$SEVERITY" \
            --output sarif \
            --file "$SARIF_FILE" 2>/dev/null || true
        grype "$TEMP_IMAGE" \
            --severity "$SEVERITY" \
            --output json \
            --file "$JSON_FILE" 2>/dev/null || true
        grype "$TEMP_IMAGE" \
            --severity "$SEVERITY" \
            --output table 2>/dev/null | tee "$TABLE_FILE" || true
        docker rmi "$TEMP_IMAGE" 2>/dev/null || true
    else
        echo "[iDevOps] WARNING: Failed to build image from Dockerfile."
        echo "[iDevOps] Scan skipped. Ensure the Dockerfile is valid and Docker is available."
    fi
    echo "[iDevOps] ::endgroup::"
fi

echo "[iDevOps] ::group::Process Results"
TOTAL_CRITICAL=0
TOTAL_HIGH=0
TOTAL_MEDIUM=0
TOTAL_LOW=0

if [ -f "$JSON_FILE" ] && [ -s "$JSON_FILE" ]; then
    TOTAL_CRITICAL=$(grep -c '"severity":"Critical"' "$JSON_FILE" 2>/dev/null || echo "0")
    TOTAL_HIGH=$(grep -c '"severity":"High"' "$JSON_FILE" 2>/dev/null || echo "0")
    TOTAL_MEDIUM=$(grep -c '"severity":"Medium"' "$JSON_FILE" 2>/dev/null || echo "0")
    TOTAL_LOW=$(grep -c '"severity":"Low"' "$JSON_FILE" 2>/dev/null || echo "0")

    echo "[iDevOps] Results Summary:"
    echo "[iDevOps]   Critical: $TOTAL_CRITICAL"
    echo "[iDevOps]   High:     $TOTAL_HIGH"
    echo "[iDevOps]   Medium:   $TOTAL_MEDIUM"
    echo "[iDevOps]   Low:      $TOTAL_LOW"
    TOTAL=$((TOTAL_CRITICAL + TOTAL_HIGH + TOTAL_MEDIUM + TOTAL_LOW))
    echo "[iDevOps]   Total:    $TOTAL"
elif [ -f "$SARIF_FILE" ] && [ -s "$SARIF_FILE" ]; then
    TOTAL_CRITICAL=$(grep -c '"level":"error"' "$SARIF_FILE" 2>/dev/null || echo "0")
    TOTAL_HIGH=$(grep -c '"level":"warning"' "$SARIF_FILE" 2>/dev/null || echo "0")
    TOTAL_MEDIUM=$(grep -c '"level":"note"' "$SARIF_FILE" 2>/dev/null || echo "0")
    TOTAL_LOW=$(grep -c '"level":"none"' "$SARIF_FILE" 2>/dev/null || echo "0")

    echo "[iDevOps] Results Summary (from SARIF):"
    echo "[iDevOps]   Critical: $TOTAL_CRITICAL"
    echo "[iDevOps]   High:     $TOTAL_HIGH"
    echo "[iDevOps]   Medium:   $TOTAL_MEDIUM"
    echo "[iDevOps]   Low:      $TOTAL_LOW"
    TOTAL=$((TOTAL_CRITICAL + TOTAL_HIGH + TOTAL_MEDIUM + TOTAL_LOW))
    echo "[iDevOps]   Total:    $TOTAL"
else
    echo "[iDevOps] No results generated. Check scan configuration."
fi
echo "[iDevOps] ::endgroup::"

echo "[iDevOps] ::group::Reports"
if [ -f "$SARIF_FILE" ] && [ -s "$SARIF_FILE" ]; then
    echo "[iDevOps] SARIF report: $SARIF_FILE"
fi
if [ -f "$JSON_FILE" ] && [ -s "$JSON_FILE" ]; then
    echo "[iDevOps] JSON report:  $JSON_FILE"
fi
if [ -f "$TABLE_FILE" ] && [ -s "$TABLE_FILE" ]; then
    echo "[iDevOps] Table report: $TABLE_FILE"
fi
echo "[iDevOps] ::endgroup::"

echo "[iDevOps] =========================================="
echo "[iDevOps] Container vulnerability scan completed."
echo "[iDevOps] Exit 0 (continue-on-error friendly)."
exit 0
