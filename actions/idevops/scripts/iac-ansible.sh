#!/usr/bin/env bash
# [iDevOps] Ansible Scanner
# Scans Ansible playbooks/roles with ansible-lint + checkov
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

run_ansible_lint() {
    log_info "Running ansible-lint..."
    install_tool "ansible-lint" "pip3 install ansible-lint" || return 0

    local output_file="${REPORT_DIR}/ansible-lint.json"
    ansible-lint -p --format json 2>&1 | tee "$output_file" || true

    parse_ansible_lint_results
}

parse_ansible_lint_results() {
    local result_file="${REPORT_DIR}/ansible-lint.json"
    if [[ -f "$result_file" ]]; then
        local counts
        counts=$(python3 -c "
import json
try:
    with open('$result_file') as f:
        data = json.load(f)
    c = h = m = l = 0
    for item in data:
        severity = item.get('severity', '').upper()
        if severity == 'CRITICAL': c += 1
        elif severity == 'HIGH': h += 1
        elif severity == 'MEDIUM': m += 1
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

run_checkov_ansible() {
    log_info "Running Checkov (Ansible)..."
    install_tool "checkov" "pip3 install checkov" || return 0

    local checkov_args=(-d "$SCAN_DIR" --framework ansible --compact)
    if [[ "$OUTPUT_FORMAT" == "sarif" ]]; then
        checkov_args+=(--output sarif --output-file "${REPORT_DIR}/checkov-ansible.sarif")
    elif [[ "$OUTPUT_FORMAT" == "json" ]]; then
        checkov_args+=(--output json --output-file "${REPORT_DIR}/checkov-ansible.json")
    fi

    checkov "${checkov_args[@]}" 2>&1 || true

    local result_file="${REPORT_DIR}/checkov-ansible.json"
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
    log_info "=== [iDevOps] Ansible Scanner ==="

    local has_ansible
    has_ansible=$(find "$SCAN_DIR" \( -name "*.yaml" -o -name "*.yml" \) -exec grep -lE "tasks:|roles:|handlers:" {} \; 2>/dev/null | head -1)

    if [[ -z "$has_ansible" ]]; then
        log_warn "No Ansible files found in ${SCAN_DIR}"
        exit 0
    fi

    run_ansible_lint
    run_checkov_ansible

    local total=$((TOTAL_CRITICAL + TOTAL_HIGH + TOTAL_MEDIUM + TOTAL_LOW))
    log_info "=== [iDevOps] Ansible Scan Complete ==="
    log_info "Findings: ${total} (Critical: ${TOTAL_CRITICAL}, High: ${TOTAL_HIGH}, Medium: ${TOTAL_MEDIUM}, Low: ${TOTAL_LOW})"

    if should_fail "$FAIL_ON"; then
        log_error "FAILED: Findings exceed ${FAIL_ON} threshold"
        exit 1
    fi

    log_success "PASSED"
    exit 0
}

main "$@"
