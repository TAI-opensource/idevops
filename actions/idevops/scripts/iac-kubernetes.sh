#!/usr/bin/env bash
# [iDevOps] Kubernetes Manifest Scanner
# Scans raw manifests, Helm charts, Kustomize with kubeconform + kube-linter + checkov + trivy
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

run_kubeconform() {
    log_info "Running Kubeconform..."
    local arch
    arch=$(uname -m)
    case "$arch" in
        x86_64)  arch="amd64" ;;
        aarch64) arch="arm64" ;;
        armv7l)  arch="arm" ;;
    esac
    local os
    os=$(uname -s | tr '[:upper:]' '[:lower:]')
    install_tool "kubeconform" "curl -sL https://github.com/yannh/kubeconform/releases/latest/download/kubeconform-${os}-${arch}.tar.gz | tar xz -C /usr/local/bin" || return 0

    local output_file="${REPORT_DIR}/kubeconform.json"
    local findings=0

    find "$SCAN_DIR" \( -name "*.yaml" -o -name "*.yml" -o -name "*.json" \) | while read -r manifest; do
        if grep -q "apiVersion:" "$manifest" 2>/dev/null; then
            local result
            result=$(kubeconform -strict -summary -output json "$manifest" 2>&1 || true)
            echo "$result" >> "${output_file}.tmp"
            local fails
            fails=$(echo "$result" | grep -c '"status":"FAIL"' || echo "0")
            findings=$((findings + fails))
        fi
    done

    if [[ -f "${output_file}.tmp" ]]; then
        python3 -c "
import json, sys
lines = []
try:
    with open('${output_file}.tmp') as f:
        for line in f:
            line = line.strip()
            if line:
                try:
                    data = json.loads(line)
                    if isinstance(data, dict) and 'resources' in data:
                        lines.extend(data['resources'])
                except:
                    pass
    with open('$output_file', 'w') as f:
        json.dump({'resources': lines}, f)
except:
    pass
" 2>/dev/null || true
        rm -f "${output_file}.tmp"
    fi

    parse_kubeconform_results
}

parse_kubeconform_results() {
    local result_file="${REPORT_DIR}/kubeconform.json"
    if [[ -f "$result_file" ]]; then
        local counts
        counts=$(python3 -c "
import json
try:
    with open('$result_file') as f:
        data = json.load(f)
    c = h = m = l = 0
    for r in data.get('resources', []):
        if r.get('status') == 'FAIL':
            c += 1
    print(f'{c} {h} {m} {l}')
except:
    print('0 0 0 0')
" 2>/dev/null || echo "0 0 0 0")
        local c h m l
        read -r c h m l <<< "$counts"
        TOTAL_CRITICAL=$((TOTAL_CRITICAL + c))
    fi
}

run_kube_linter() {
    log_info "Running Kube-linter..."
    local arch
    arch=$(uname -m)
    case "$arch" in
        x86_64)  arch="amd64" ;;
        aarch64) arch="arm64" ;;
        armv7l)  arch="armv7" ;;
    esac
    install_tool "kube-linter" "curl -sL https://github.com/stackrox/kube-linter/releases/latest/download/kube-linter-linux-${arch} -o /usr/local/bin/kube-linter && chmod +x /usr/local/bin/kube-linter" || return 0

    local output_file="${REPORT_DIR}/kube-linter.json"
    local scan_targets=()

    while IFS= read -r manifest; do
        if grep -q "apiVersion:" "$manifest" 2>/dev/null; then
            scan_targets+=("$manifest")
        fi
    done < <(find "$SCAN_DIR" \( -name "*.yaml" -o -name "*.yml" -o -name "*.json" \) 2>/dev/null)

    if [[ ${#scan_targets[@]} -gt 0 ]]; then
        kube-linter lint "${scan_targets[@]}" --format json > "$output_file" 2>&1 || true
    fi

    parse_kube_linter_results
}

parse_kube_linter_results() {
    local result_file="${REPORT_DIR}/kube-linter.json"
    if [[ -f "$result_file" ]]; then
        local counts
        counts=$(python3 -c "
import json
try:
    with open('$result_file') as f:
        data = json.load(f)
    c = h = m = l = 0
    for r in data:
        sev = r.get('severity', '').upper()
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

run_checkov_kubernetes() {
    log_info "Running Checkov (Kubernetes)..."
    install_tool "checkov" "pip3 install checkov" || return 0

    local checkov_args=(-d "$SCAN_DIR" --framework kubernetes --compact)
    if [[ "$OUTPUT_FORMAT" == "sarif" ]]; then
        checkov_args+=(--output sarif --output-file "${REPORT_DIR}/checkov-kubernetes.sarif")
    elif [[ "$OUTPUT_FORMAT" == "json" ]]; then
        checkov_args+=(--output json --output-file "${REPORT_DIR}/checkov-kubernetes.json")
    fi

    checkov "${checkov_args[@]}" 2>&1 || true

    local result_file="${REPORT_DIR}/checkov-kubernetes.json"
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

run_trivy_kubernetes() {
    log_info "Running Trivy (Kubernetes config)..."
    install_tool "trivy" "curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh | sh -s -- -b /usr/local/bin" || return 0

    timeout 180 trivy config "$SCAN_DIR" --severity CRITICAL,HIGH,MEDIUM,LOW --format json --output "${REPORT_DIR}/trivy-kubernetes.json" 2>&1 || true

    if [[ -f "${REPORT_DIR}/trivy-kubernetes.json" ]]; then
        local counts
        counts=$(python3 -c "
import json
try:
    with open('${REPORT_DIR}/trivy-kubernetes.json') as f:
        data = json.load(f)
    c = h = m = l = 0
    for result in data.get('Results', []):
        for v in result.get('Vulnerabilities', []):
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
    log_info "=== [iDevOps] Kubernetes Scanner ==="

    local has_k8s
    has_k8s=$(find "$SCAN_DIR" \( -name "*.yaml" -o -name "*.yml" -o -name "*.json" \) -exec grep -l "apiVersion:" {} \; 2>/dev/null | head -1)

    if [[ -z "$has_k8s" ]]; then
        log_warn "No Kubernetes manifests found in ${SCAN_DIR}"
        exit 0
    fi

    run_kubeconform
    run_kube_linter
    run_checkov_kubernetes
    run_trivy_kubernetes

    local total=$((TOTAL_CRITICAL + TOTAL_HIGH + TOTAL_MEDIUM + TOTAL_LOW))
    log_info "=== [iDevOps] Kubernetes Scan Complete ==="
    log_info "Findings: ${total} (Critical: ${TOTAL_CRITICAL}, High: ${TOTAL_HIGH}, Medium: ${TOTAL_MEDIUM}, Low: ${TOTAL_LOW})"

    if should_fail "$FAIL_ON"; then
        log_error "FAILED: Findings exceed ${FAIL_ON} threshold"
        exit 1
    fi

    log_success "PASSED"
    exit 0
}

main "$@"
