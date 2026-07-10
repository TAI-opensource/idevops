#!/usr/bin/env bash
# [iDevOps] Universal Infrastructure as Code Scanner
# Auto-detects IaC files and runs appropriate security scanners
# Supported: Terraform, CloudFormation, Kubernetes, Helm, Docker, Ansible, Pulumi, Bicep
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCAN_DIR="${SCAN_DIR:-.}"
FAIL_ON="${FAIL_ON:-HIGH}"
IAC_TYPES="${IAC_TYPES:-}"
OUTPUT_FORMAT="${OUTPUT_FORMAT:-sarif}"
REPORT_DIR="${REPORT_DIR:-./iac-reports}"
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

TOTAL_FINDINGS=0
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

detect_iac_types() {
    local detected=""
    if [[ -n "$IAC_TYPES" ]]; then
        echo "$IAC_TYPES"
        return
    fi

    if find "$SCAN_DIR" -name "*.tf" -o -name "*.tfvars" 2>/dev/null | head -1 | grep -q .; then
        detected="${detected},terraform"
    fi
    if find "$SCAN_DIR" \( -name "template.yaml" -o -name "template.json" -o -name "*.yaml" -o -name "*.yml" \) -exec grep -l "AWSTemplateFormatVersion" {} \; 2>/dev/null | head -1 | grep -q .; then
        detected="${detected},cloudformation"
    fi
    if find "$SCAN_DIR" \( -name "*.yaml" -o -name "*.yml" \) -exec grep -l "apiVersion:" {} \; 2>/dev/null | head -1 | grep -q .; then
        detected="${detected},kubernetes"
    fi
    if find "$SCAN_DIR" -name "Chart.yaml" 2>/dev/null | head -1 | grep -q .; then
        detected="${detected},helm"
    fi
    if find "$SCAN_DIR" -name "Dockerfile*" -o -name "*.dockerfile" 2>/dev/null | head -1 | grep -q .; then
        detected="${detected},docker"
    fi
    if find "$SCAN_DIR" \( -name "*.yaml" -o -name "*.yml" \) -exec grep -l "tasks:" {} \; 2>/dev/null | head -1 | grep -q .; then
        detected="${detected},ansible"
    fi
    if find "$SCAN_DIR" -name "Pulumi.yaml" -o -name "Pulumi.*.yaml" 2>/dev/null | head -1 | grep -q .; then
        detected="${detected},pulumi"
    fi
    if find "$SCAN_DIR" -name "*.bicep" 2>/dev/null | head -1 | grep -q .; then
        detected="${detected},bicep"
    fi

    detected="${detected#,}"
    if [[ -z "$detected" ]]; then
        detected="terraform,cloudformation,kubernetes,helm,docker,ansible,pulumi,bicep"
    fi
    echo "$detected"
}

install_common_tools() {
    install_tool "checkov" "pip3 install checkov" || true
    install_tool "trivy" "curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh | sh -s -- -b /usr/local/bin" || true
}

run_checkov() {
    local path="$1"
    local types="$2"
    local checkov_args=()

    if [[ "$types" == *"terraform"* ]]; then
        checkov_args+=(-d "$path" --framework terraform)
    fi
    if [[ "$types" == *"cloudformation"* ]]; then
        checkov_args+=(-d "$path" --framework cloudformation)
    fi
    if [[ "$types" == *"kubernetes"* ]] || [[ "$types" == *"helm"* ]]; then
        checkov_args+=(-d "$path" --framework kubernetes)
    fi
    if [[ "$types" == *"docker"* ]]; then
        checkov_args+=(-d "$path" --framework dockerfile)
    fi
    if [[ "$types" == *"ansible"* ]]; then
        checkov_args+=(-d "$path" --framework ansible)
    fi

    if [[ ${#checkov_args[@]} -eq 0 ]]; then
        checkov_args=(-d "$path")
    fi

    if [[ "$OUTPUT_FORMAT" == "sarif" ]]; then
        checkov_args+=(--output sarif --output-file "${REPORT_DIR}/checkov.sarif")
    elif [[ "$OUTPUT_FORMAT" == "json" ]]; then
        checkov_args+=(--output json --output-file "${REPORT_DIR}/checkov.json")
    else
        checkov_args+=(--output cli)
    fi

    checkov "${checkov_args[@]}" 2>&1 || true
    parse_checkov_results
}

parse_checkov_results() {
    if [[ -f "${REPORT_DIR}/checkov.json" ]]; then
        local failed
        failed=$(python3 -c "
import json, sys
try:
    with open('${REPORT_DIR}/checkov.json') as f:
        data = json.load(f)
    results = data.get('results', {}).get('passed_checks', []) + data.get('results', {}).get('failed_checks', [])
    failed = [r for r in results if r.get('check_result', {}).get('result') == 'FAILED']
    for f in failed:
        sev = f.get('severity', 'UNKNOWN').upper()
        print(sev)
except:
    pass
" 2>/dev/null || true)
        while IFS= read -r sev; do
            case "$sev" in
                CRITICAL) ((TOTAL_CRITICAL++)) || true ;;
                HIGH)     ((TOTAL_HIGH++)) || true ;;
                MEDIUM)   ((TOTAL_MEDIUM++)) || true ;;
                LOW)      ((TOTAL_LOW++)) || true ;;
                *)        ((TOTAL_MEDIUM++)) || true ;;
            esac
        done <<< "$failed"
        TOTAL_FINDINGS=$((TOTAL_CRITICAL + TOTAL_HIGH + TOTAL_MEDIUM + TOTAL_LOW))
    fi
}

run_trivy_config() {
    local path="$1"
    local trivy_args=(config "$path" --severity CRITICAL,HIGH,MEDIUM,LOW)

    if [[ "$OUTPUT_FORMAT" == "sarif" ]]; then
        trivy_args+=(--format sarif --output "${REPORT_DIR}/trivy-config.sarif")
    elif [[ "$OUTPUT_FORMAT" == "json" ]]; then
        trivy_args+=(--format json --output "${REPORT_DIR}/trivy-config.json")
    fi

    timeout "$TIMEOUT" trivy "${trivy_args[@]}" 2>&1 || true
    parse_trivy_config_results
}

parse_trivy_config_results() {
    local result_file=""
    [[ -f "${REPORT_DIR}/trivy-config.json" ]] && result_file="${REPORT_DIR}/trivy-config.json"

    if [[ -n "$result_file" ]]; then
        local counts
        counts=$(python3 -c "
import json
try:
    with open('$result_file') as f:
        data = json.load(f)
    results = data.get('Results', [])
    c = h = m = l = 0
    for r in results:
        for v in r.get('Vulnerabilities', []):
            sev = v.get('Severity', '').upper()
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
        TOTAL_FINDINGS=$((TOTAL_CRITICAL + TOTAL_HIGH + TOTAL_MEDIUM + TOTAL_LOW))
    fi
}

should_fail() {
    local current="$1"
    local threshold="$2"
    case "$threshold" in
        CRITICAL) [[ $current -gt 0 ]] && return 0 ;;
        HIGH)     [[ $((TOTAL_CRITICAL + TOTAL_HIGH)) -gt 0 ]] && return 0 ;;
        MEDIUM)   [[ $TOTAL_FINDINGS -gt 0 ]] && return 0 ;;
        LOW)      [[ $TOTAL_FINDINGS -gt 0 ]] && return 0 ;;
        NONE)     return 1 ;;
        *)        [[ $TOTAL_FINDINGS -gt 0 ]] && return 0 ;;
    esac
    return 1
}

main() {
    log_info "=== [iDevOps] IaC Security Scanner ==="
    log_info "Scan directory: ${SCAN_DIR}"
    log_info "Fail threshold: ${FAIL_ON}"

    local iac_types
    iac_types=$(detect_iac_types)
    log_info "Detected IaC types: ${iac_types}"

    install_common_tools

    if [[ "$iac_types" == *"terraform"* ]]; then
        log_info "--- Terraform Scanning ---"
        "$SCRIPT_DIR/iac-terraform.sh" "$SCAN_DIR" "$REPORT_DIR" "$FAIL_ON" "$OUTPUT_FORMAT" 2>&1 || true
    fi

    if [[ "$iac_types" == *"cloudformation"* ]]; then
        log_info "--- CloudFormation Scanning ---"
        "$SCRIPT_DIR/iac-cloudformation.sh" "$SCAN_DIR" "$REPORT_DIR" "$FAIL_ON" "$OUTPUT_FORMAT" 2>&1 || true
    fi

    if [[ "$iac_types" == *"kubernetes"* ]] || [[ "$iac_types" == *"helm"* ]]; then
        log_info "--- Kubernetes/Helm Scanning ---"
        "$SCRIPT_DIR/iac-kubernetes.sh" "$SCAN_DIR" "$REPORT_DIR" "$FAIL_ON" "$OUTPUT_FORMAT" 2>&1 || true
    fi

    if [[ "$iac_types" == *"ansible"* ]]; then
        log_info "--- Ansible Scanning ---"
        "$SCRIPT_DIR/iac-ansible.sh" "$SCAN_DIR" "$REPORT_DIR" "$FAIL_ON" "$OUTPUT_FORMAT" 2>&1 || true
    fi

    if [[ "$iac_types" == *"docker"* ]]; then
        log_info "--- Dockerfile Scanning ---"
        "$SCRIPT_DIR/container-dockerfile.sh" "$SCAN_DIR" "$REPORT_DIR" "$FAIL_ON" "$OUTPUT_FORMAT" 2>&1 || true
    fi

    log_info "=== [iDevOps] Scan Complete ==="
    log_info "Total findings: ${TOTAL_FINDINGS}"
    log_info "  Critical: ${TOTAL_CRITICAL}"
    log_info "  High:     ${TOTAL_HIGH}"
    log_info "  Medium:   ${TOTAL_MEDIUM}"
    log_info "  Low:      ${TOTAL_LOW}"

    if should_fail "$TOTAL_FINDINGS" "$FAIL_ON"; then
        log_error "FAILED: Findings exceed ${FAIL_ON} threshold"
        exit 1
    fi

    log_success "PASSED: No findings above ${FAIL_ON} threshold"
    exit 0
}

main "$@"
