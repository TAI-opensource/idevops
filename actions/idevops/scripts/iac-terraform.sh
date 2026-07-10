#!/usr/bin/env bash
# [iDevOps] Terraform IaC Scanner
# Scans Terraform files with tflint + checkov + trivy + fmt + validate
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
FORMAT_ISSUES=0

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

run_terraform_fmt() {
    log_info "Running terraform fmt check..."
    local fmt_issues
    fmt_issues=$(find "$SCAN_DIR" -name "*.tf" -exec terraform fmt -check -diff {} \; 2>&1 || true)
    if [[ -n "$fmt_issues" ]]; then
        FORMAT_ISSUES=$(echo "$fmt_issues" | grep -c "^" || echo "0")
        log_warn "Found ${FORMAT_ISSUES} formatting issues"
        echo "$fmt_issues" > "${REPORT_DIR}/terraform-fmt.txt"
    else
        log_success "No formatting issues found"
    fi
}

run_terraform_validate() {
    log_info "Running terraform validate..."
    local tf_dir
    tf_dir=$(find "$SCAN_DIR" -name "*.tf" -printf '%h\n' | head -1)
    if [[ -n "$tf_dir" ]]; then
        (
            cd "$tf_dir" 2>/dev/null || exit 0
            terraform init -backend=false >/dev/null 2>&1 || true
            terraform validate 2>&1 | tee "${REPORT_DIR}/terraform-validate.txt" || true
        )
    fi
}

run_tflint() {
    log_info "Running TFLint..."
    install_tool "tflint" "curl -s https://raw.githubusercontent.com/terraform-linters/tflint/master/install_linux.sh | bash" || return 0

    local tflint_args=(--format json --output "${REPORT_DIR}/tflint.json")

    local provider="${TFLINT_PROVIDER:-aws}"
    if [[ -n "${TFLINT_RULES:-}" ]]; then
        local rules_file="${REPORT_DIR}/.tflint.hcl"
        cat > "$rules_file" <<EOF
plugin "aws" {
  enabled = true
}
plugin "azurerm" {
  enabled = false
}
plugin "google" {
  enabled = false
}
EOF
        tflint_args+=(--config "$rules_file")
    fi

    find "$SCAN_DIR" -name "*.tf" -printf '%h\n' | sort -u | while read -r dir; do
        (cd "$dir" && timeout 120 tflint "${tflint_args[@]}" 2>&1 || true)
    done

    parse_tflint_results
}

parse_tflint_results() {
    if [[ -f "${REPORT_DIR}/tflint.json" ]]; then
        local counts
        counts=$(python3 -c "
import json
try:
    with open('${REPORT_DIR}/tflint.json') as f:
        data = json.load(f)
    issues = data.get('issues', [])
    c = h = m = l = 0
    for issue in issues:
        sev = issue.get('severity', 'warning').lower()
        if sev == 'error': c += 1
        elif sev == 'warning': m += 1
        else: l += 1
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

run_checkov_terraform() {
    log_info "Running Checkov (Terraform)..."
    install_tool "checkov" "pip3 install checkov" || return 0

    local checkov_args=(-d "$SCAN_DIR" --framework terraform --compact)
    if [[ "$OUTPUT_FORMAT" == "sarif" ]]; then
        checkov_args+=(--output sarif --output-file "${REPORT_DIR}/checkov-terraform.sarif")
    elif [[ "$OUTPUT_FORMAT" == "json" ]]; then
        checkov_args+=(--output json --output-file "${REPORT_DIR}/checkov-terraform.json")
    fi

    checkov "${checkov_args[@]}" 2>&1 || true
    parse_checkov_results
}

parse_checkov_results() {
    local result_file="${REPORT_DIR}/checkov-terraform.json"
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

run_trivy_terraform() {
    log_info "Running Trivy (Terraform)..."
    install_tool "trivy" "curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh | sh -s -- -b /usr/local/bin" || return 0

    local trivy_args=(config "$SCAN_DIR" --severity CRITICAL,HIGH,MEDIUM,LOW --format json --output "${REPORT_DIR}/trivy-terraform.json")
    timeout 180 trivy "${trivy_args[@]}" 2>&1 || true
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
    log_info "=== [iDevOps] Terraform Scanner ==="

    if ! find "$SCAN_DIR" -name "*.tf" 2>/dev/null | head -1 | grep -q .; then
        log_warn "No Terraform files found in ${SCAN_DIR}"
        exit 0
    fi

    run_terraform_fmt
    run_terraform_validate
    run_tflint
    run_checkov_terraform
    run_trivy_terraform

    local total=$((TOTAL_CRITICAL + TOTAL_HIGH + TOTAL_MEDIUM + TOTAL_LOW))
    log_info "=== [iDevOps] Terraform Scan Complete ==="
    log_info "Findings: ${total} (Critical: ${TOTAL_CRITICAL}, High: ${TOTAL_HIGH}, Medium: ${TOTAL_MEDIUM}, Low: ${TOTAL_LOW})"

    if should_fail "$FAIL_ON"; then
        log_error "FAILED: Findings exceed ${FAIL_ON} threshold"
        exit 1
    fi

    log_success "PASSED"
    exit 0
}

main "$@"
