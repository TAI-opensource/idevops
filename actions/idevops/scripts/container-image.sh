#!/usr/bin/env bash
# [iDevOps] Container Image Scanner
# Scans container images with Trivy + Grype + Syft SBOM
set -euo pipefail

CONTAINER_IMAGE="${1:-}"
REPORT_DIR="${2:-./container-reports}"
FAIL_ON="${3:-HIGH}"
TIMEOUT="${4:-300}"

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
LICENSE_ISSUES=0

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

run_trivy_image() {
    log_info "Running Trivy image scan..."
    install_tool "trivy" "curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh | sh -s -- -b /usr/local/bin" || return 0

    local output_file="${REPORT_DIR}/trivy-image.json"
    timeout "$TIMEOUT" trivy image \
        --format json \
        --output "$output_file" \
        --severity CRITICAL,HIGH,MEDIUM,LOW \
        --scanners vuln,secret,misconfig \
        "$CONTAINER_IMAGE" 2>&1 || true

    parse_trivy_results
}

parse_trivy_results() {
    local result_file="${REPORT_DIR}/trivy-image.json"
    if [[ -f "$result_file" ]]; then
        local counts
        counts=$(python3 -c "
import json
try:
    with open('$result_file') as f:
        data = json.load(f)
    c = h = m = l = 0
    for result in data.get('Results', []):
        for v in result.get('Vulnerabilities', []):
            sev = v.get('Severity', '').upper()
            if sev == 'CRITICAL': c += 1
            elif sev == 'HIGH': h += 1
            elif sev == 'MEDIUM': m += 1
            else: l += 1
        for s in result.get('Secrets', []):
            c += 1
    print(f'{c} {h} {m} {l}')
except:
    print('0 0 0 0')
" 2>/dev/null || echo "0 0 0 0")
        local c h m l
        read -r c h m l <<< "$counts"
        TOTAL_CRITICAL=$((TOTAL_CRITICAL + c))
        TOTAL_HIGH=$((TOTAL_HIGH + h))
        TOTAL_MEDIUM=$((TOTAL_MEDIUM + m))
        TOTAL_LOW=$((TOTAL_LOW + l))
    fi
}

run_grype() {
    log_info "Running Grype scan..."
    install_tool "grype" "curl -sSfL https://raw.githubusercontent.com/anchore/grype/main/install.sh | sh -s -- -b /usr/local/bin" || return 0

    local output_file="${REPORT_DIR}/grype.json"
    timeout "$TIMEOUT" grype "$CONTAINER_IMAGE" -o json > "$output_file" 2>&1 || true

    parse_grype_results
}

parse_grype_results() {
    local result_file="${REPORT_DIR}/grype.json"
    if [[ -f "$result_file" ]]; then
        local counts
        counts=$(python3 -c "
import json
try:
    with open('$result_file') as f:
        data = json.load(f)
    c = h = m = l = 0
    for match in data.get('matches', []):
        sev = match.get('vulnerability', {}).get('severity', '').upper()
        if sev == 'CRITICAL': c += 1
        elif sev == 'HIGH': h += 1
        elif sev == 'MEDIUM': m += 1
        else: l += 1
    print(f'{c} {h} {m} {l}')
except:
    print('0 0 0 0')
" 2>/dev/null || echo "0 0 0 0")
        local c h m l
        read -r c h m l <<< "$counts"
        TOTAL_CRITICAL=$((TOTAL_CRITICAL + c))
        TOTAL_HIGH=$((TOTAL_HIGH + h))
        TOTAL_MEDIUM=$((TOTAL_MEDIUM + m))
        TOTAL_LOW=$((TOTAL_LOW + l))
    fi
}

run_syft_sbom() {
    log_info "Generating SBOM with Syft..."
    install_tool "syft" "curl -sSfL https://raw.githubusercontent.com/anchore/syft/main/install.sh | sh -s -- -b /usr/local/bin" || return 0

    local sbom_file="${REPORT_DIR}/sbom.json"
    timeout "$TIMEOUT" syft "$CONTAINER_IMAGE" -o json > "$sbom_file" 2>&1 || true

    local component_count
    component_count=$(python3 -c "
import json
try:
    with open('$sbom_file') as f:
        data = json.load(f)
    print(len(data.get('artifacts', [])))
except:
    print('0')
" 2>/dev/null || echo "0")
    log_info "SBOM generated: ${component_count} components cataloged"

    local spdx_file="${REPORT_DIR}/sbom.spdx.json"
    timeout "$TIMEOUT" syft "$CONTAINER_IMAGE" -o spdx-json > "$spdx_file" 2>&1 || true

    local cdx_file="${REPORT_DIR}/sbom.cdx.json"
    timeout "$TIMEOUT" syft "$CONTAINER_IMAGE" -o cyclonedx-json > "$cdx_file" 2>&1 || true
}

run_license_check() {
    log_info "Checking licenses..."
    if [[ -f "${REPORT_DIR}/sbom.json" ]]; then
        local license_issues
        license_issues=$(python3 -c "
import json
try:
    with open('${REPORT_DIR}/sbom.json') as f:
        data = json.load(f)
    problematic = ['GPL-3.0', 'GPL-3.0-only', 'AGPL-3.0', 'AGPL-3.0-only', 'SSPL-1.0', 'BSL-1.1']
    issues = []
    for pkg in data.get('artifacts', []):
        lic = pkg.get('licenses', [])
        for l in lic:
            name = l.get('value', '') if isinstance(l, dict) else str(l)
            if any(p in name for p in problematic):
                issues.append(f'{pkg.get(\"name\", \"unknown\")}: {name}')
    for i in issues:
        print(i)
except:
    pass
" 2>/dev/null || true)
        if [[ -n "$license_issues" ]]; then
            log_warn "License compliance issues found:"
            echo "$license_issues"
            echo "$license_issues" > "${REPORT_DIR}/license-issues.txt"
            LICENSE_ISSUES=$(echo "$license_issues" | wc -l)
            TOTAL_MEDIUM=$((TOTAL_MEDIUM + LICENSE_ISSUES))
        else
            log_success "No problematic licenses detected"
        fi
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
    log_info "=== [iDevOps] Container Image Scanner ==="

    if [[ -z "$CONTAINER_IMAGE" ]]; then
        log_error "CONTAINER_IMAGE not set"
        exit 1
    fi

    log_info "Scanning image: ${CONTAINER_IMAGE}"

    run_trivy_image
    run_grype
    run_syft_sbom
    run_license_check

    local total=$((TOTAL_CRITICAL + TOTAL_HIGH + TOTAL_MEDIUM + TOTAL_LOW))
    log_info "=== [iDevOps] Image Scan Complete ==="
    log_info "Findings: ${total} (Critical: ${TOTAL_CRITICAL}, High: ${TOTAL_HIGH}, Medium: ${TOTAL_MEDIUM}, Low: ${TOTAL_LOW})"
    log_info "Reports saved to: ${REPORT_DIR}"

    if should_fail "$FAIL_ON"; then
        log_error "FAILED: Findings exceed ${FAIL_ON} threshold"
        exit 1
    fi

    log_success "PASSED"
    exit 0
}

main "$@"
