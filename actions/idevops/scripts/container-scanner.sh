#!/usr/bin/env bash
# [iDevOps] Container Security Scanner
# Scans Dockerfiles and container images with Hadolint + Dockle + Trivy + Grype + Syft
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONTAINER_IMAGE="${CONTAINER_IMAGE:-}"
DOCKERFILE_PATH="${DOCKERFILE_PATH:-}"
SCAN_DIR="${SCAN_DIR:-.}"
FAIL_ON="${FAIL_ON:-HIGH}"
REPORT_DIR="${REPORT_DIR:-./container-reports}"
TIMEOUT="${TIMEOUT:-300}"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info()    { echo -e "${BLUE}[iDevOps]${NC} $*"; }
log_success() { echo -e "${GREEN}[iDevOps]${NC} $*"; }
log_warn()    { echo -e "${YELLOW}[iDevOps]${NC} $*"; }
log_error()   { echo -e "${RED}[iDevOps]${NC} $*"; }

mkdir -p "${REPORT_DIR}"

TOTAL_CRITICAL=0
TOTAL_HIGH=0
TOTAL_MEDIUM=0
TOTAL_LOW=0

install_tool() {
    local tool="$1"
    local install_cmd="$2"
    if ! command -v "$tool" &>/dev/null; then
        log_info "Installing ${tool}..."
        eval "$install_cmd" >/dev/null 2>&1 || {
            log_warn "Failed to install ${tool} - skipping"
            return 1
        }
    fi
    return 0
}

detect_dockerfiles() {
    if [[ -n "$DOCKERFILE_PATH" ]]; then
        echo "$DOCKERFILE_PATH"
        return
    fi
    find "$SCAN_DIR" \( -name "Dockerfile*" -o -name "*.dockerfile" \) 2>/dev/null
}

run_dockerfile_checks() {
    log_info "--- Dockerfile Security Checks ---"
    "$SCRIPT_DIR/container-dockerfile.sh" "$SCAN_DIR" "$REPORT_DIR" "$FAIL_ON" 2>&1 || true
}

run_image_scan() {
    if [[ -z "$CONTAINER_IMAGE" ]]; then
        log_info "--- Image Scanning ---"
        "$SCRIPT_DIR/container-image.sh" "$CONTAINER_IMAGE" "$REPORT_DIR" "$FAIL_ON" 2>&1 || true
    fi
}

run_secrets_check() {
    log_info "--- Secrets Detection in Image ---"
    if [[ -n "$CONTAINER_IMAGE" ]] && command -v docker &>/dev/null; then
        local tmpdir
        tmpdir=$(mktemp -d)
        docker export "$(docker create "$CONTAINER_IMAGE" 2>/dev/null)" > "${tmpdir}/layer.tar" 2>/dev/null || true
        if [[ -f "${tmpdir}/layer.tar" ]]; then
            local secrets_found
            secrets_found=$(tar xf "${tmpdir}/layer.tar" -C "$tmpdir" 2>/dev/null; \
                grep -rn -i -E "(password|secret|api_key|token|credential)" "$tmpdir" \
                --include="*.txt" --include="*.env" --include="*.cfg" --include="*.conf" --include="*.ini" \
                --exclude="*.tar" 2>/dev/null | head -20 || true)
            if [[ -n "$secrets_found" ]]; then
                log_warn "Potential secrets found in image:"
                echo "$secrets_found"
                echo "$secrets_found" > "${REPORT_DIR}/secrets-findings.txt"
                ((TOTAL_HIGH++)) || true
            else
                log_success "No obvious secrets detected in image"
            fi
            docker rm "$(docker create "$CONTAINER_IMAGE" 2>/dev/null)" 2>/dev/null || true
        fi
        rm -rf "$tmpdir"
    else
        log_info "Docker not available or no image specified - skipping secrets check"
    fi
}

should_fail() {
    local threshold="$1"
    local total=$((TOTAL_CRITICAL + TOTAL_HIGH + TOTAL_MEDIUM + TOTAL_LOW))
    case "$threshold" in
        CRITICAL) [[ $TOTAL_CRITICAL -gt 0 ]] && return 0 ;;
        HIGH)     [[ $((TOTAL_CRITICAL + TOTAL_HIGH)) -gt 0 ]] && return 0 ;;
        MEDIUM)   [[ $total -gt 0 ]] && return 0 ;;
        LOW)      [[ $total -gt 0 ]] && return 0 ;;
        NONE)     return 1 ;;
        *)        [[ $total -gt 0 ]] && return 0 ;;
    esac
    return 1
}

main() {
    log_info "=== [iDevOps] Container Security Scanner ==="
    log_info "Image: ${CONTAINER_IMAGE:-not set}"
    log_info "Dockerfile: ${DOCKERFILE_PATH:-auto-detect}"

    local dockerfiles
    dockerfiles=$(detect_dockerfiles)

    if [[ -z "$dockerfiles" ]] && [[ -z "$CONTAINER_IMAGE" ]]; then
        log_warn "No Dockerfiles or container image found"
        exit 0
    fi

    if [[ -n "$dockerfiles" ]]; then
        log_info "Found Dockerfiles:"
        echo "$dockerfiles"
    fi

    run_dockerfile_checks
    run_image_scan
    run_secrets_check

    local total=$((TOTAL_CRITICAL + TOTAL_HIGH + TOTAL_MEDIUM + TOTAL_LOW))
    log_info "=== [iDevOps] Container Scan Complete ==="
    log_info "Findings: ${total} (Critical: ${TOTAL_CRITICAL}, High: ${TOTAL_HIGH}, Medium: ${TOTAL_MEDIUM}, Low: ${TOTAL_LOW})"

    if should_fail "$FAIL_ON"; then
        log_error "FAILED: Findings exceed ${FAIL_ON} threshold"
        exit 1
    fi

    log_success "PASSED"
    exit 0
}

main "$@"
