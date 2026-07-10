#!/usr/bin/env bash
# [iDevOps] CloudFormation Scanner
# Scans AWS CloudFormation templates with cfn-lint + checkov + taskcat
set -euo pipefail

SCAN_DIR="${1:-.}"
REPORT_DIR="${2:-./iac-reports}"
FAIL_ON="${3:-HIGH}"
OUTPUT_FORMAT="${4:-sarif}"

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

run_cfn_lint() {
    log_info "Running cfn-lint..."
    install_tool "cfn-lint" "pip3 install cfn-lint" || return 0

    local templates=()
    while IFS= read -r template; do
        templates+=("$template")
    done < <(find "$SCAN_DIR" \( -name "*.yaml" -o -name "*.yml" -o -name "*.json" \) -exec grep -l "AWSTemplateFormatVersion" {} \; 2>/dev/null)

    if [[ ${#templates[@]} -eq 0 ]]; then
        log_warn "No CloudFormation templates found"
        return
    fi

    local output_file="${REPORT_DIR}/cfn-lint.json"
    cfn-lint --format json --output-file "$output_file" "${templates[@]}" 2>&1 || true

    parse_cfn_lint_results
}

parse_cfn_lint_results() {
    local result_file="${REPORT_DIR}/cfn-lint.json"
    if [[ -f "$result_file" ]]; then
        local counts
        counts=$(python3 -c "
import json
try:
    with open('$result_file') as f:
        data = json.load(f)
    c = h = m = l = 0
    for match in data:
        level = match.get('Level', '').upper()
        if level == 'ERROR': c += 1
        elif level == 'WARNING': m += 1
        elif level == 'INFO': l += 1
        else: m += 1
    print(f'{c} {h} {m} {l}')
except:
    print('0 0 0 0')
" 2>/dev/null || echo "0 0 0 0")
        local c h m l
        read -r c h m l <<< "$counts"
        TOTAL_CRITICAL=$((TOTAL_CRITICAL + c))
        TOTAL_MEDIUM=$((TOTAL_MEDIUM + m))
        TOTAL_LOW=$((TOTAL_LOW + l))
    fi
}

run_checkov_cloudformation() {
    log_info "Running Checkov (CloudFormation)..."
    install_tool "checkov" "pip3 install checkov" || return 0

    local checkov_args=(-d "$SCAN_DIR" --framework cloudformation --compact)
    if [[ "$OUTPUT_FORMAT" == "sarif" ]]; then
        checkov_args+=(--output sarif --output-file "${REPORT_DIR}/checkov-cloudformation.sarif")
    elif [[ "$OUTPUT_FORMAT" == "json" ]]; then
        checkov_args+=(--output json --output-file "${REPORT_DIR}/checkov-cloudformation.json")
    fi

    checkov "${checkov_args[@]}" 2>&1 || true

    local result_file="${REPORT_DIR}/checkov-cloudformation.json"
    if [[ -f "$result_file" ]]; then
        local counts
        counts=$(python3 -c "
import json
try:
    with open('$result_file') as f:
        data = json.load(f)
    results = data.get('results', {}).get('failed_checks', [])
    c = h = m = l = 0
    for r in results:
        sev = r.get('severity', 'UNKNOWN').upper()
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

run_taskcat() {
    log_info "Running taskcat..."
    if command -v taskcat &>/dev/null; then
        taskcat test run 2>&1 | tee "${REPORT_DIR}/taskcat.txt" || true
    else
        log_info "taskcat not found - skipping (pip3 install taskcat to enable)"
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
    log_info "=== [iDevOps] CloudFormation Scanner ==="

    local has_cfn
    has_cfn=$(find "$SCAN_DIR" \( -name "*.yaml" -o -name "*.yml" -o -name "*.json" \) -exec grep -l "AWSTemplateFormatVersion" {} \; 2>/dev/null | head -1)

    if [[ -z "$has_cfn" ]]; then
        log_warn "No CloudFormation templates found in ${SCAN_DIR}"
        exit 0
    fi

    run_cfn_lint
    run_checkov_cloudformation
    run_taskcat

    local total=$((TOTAL_CRITICAL + TOTAL_HIGH + TOTAL_MEDIUM + TOTAL_LOW))
    log_info "=== [iDevOps] CloudFormation Scan Complete ==="
    log_info "Findings: ${total} (Critical: ${TOTAL_CRITICAL}, High: ${TOTAL_HIGH}, Medium: ${TOTAL_MEDIUM}, Low: ${TOTAL_LOW})"

    if should_fail "$FAIL_ON"; then
        log_error "FAILED: Findings exceed ${FAIL_ON} threshold"
        exit 1
    fi

    log_success "PASSED"
    exit 0
}

main "$@"
