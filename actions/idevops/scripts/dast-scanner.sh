#!/usr/bin/env bash
# [iDevOps] DAST Scanner
# Dynamic Application Security Testing with OWASP ZAP + Nuclei + httpx
set -euo pipefail

TARGET_URL="${TARGET_URL:-}"
DAST_OPTIONS="${DAST_OPTIONS:-}"
SCAN_DIR="${SCAN_DIR:-.}"
FAIL_ON="${FAIL_ON:-HIGH}"
REPORT_DIR="${REPORT_DIR:-./dast-reports}"
TIMEOUT="${TIMEOUT:-600}"
ZAP_IMAGE="${ZAP_IMAGE:-ghcr.io/zaproxy/zaproxy:stable}"

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

run_zap_scan() {
    log_info "Running OWASP ZAP scan..."
    if ! command -v docker &>/dev/null; then
        log_warn "Docker not available - skipping ZAP scan"
        return
    fi

    local output_dir="${REPORT_DIR}/zap"
    mkdir -p "$output_dir"

    local zap_args=(
        -t "$TARGET_URL"
        -r "${TARGET_URL//[^a-zA-Z0-9]/_}-report.html"
        -J "${TARGET_URL//[^a-zA-Z0-9]/_}-report.json"
    )

    if [[ -n "$DAST_OPTIONS" ]]; then
        IFS=',' read -ra extra_opts <<< "$DAST_OPTIONS"
        zap_args+=("${extra_opts[@]}")
    fi

    timeout "$TIMEOUT" docker run --rm \
        -v "$output_dir:/zap/wrk/" \
        -t "$ZAP_IMAGE" \
        zap-full-scan.py "${zap_args[@]}" 2>&1 | tee "${output_dir}/zap-output.txt" || true

    parse_zap_results
}

parse_zap_results() {
    local output_dir="${REPORT_DIR}/zap"
    local json_report
    json_report=$(find "$output_dir" -name "*report.json" | head -1)

    if [[ -n "$json_report" ]] && [[ -f "$json_report" ]]; then
        local counts
        counts=$(python3 -c "
import json
try:
    with open('$json_report') as f:
        data = json.load(f)
    c = h = m = l = 0
    for site in data.get('site', []):
        for alert in site.get('alerts', []):
            risk = alert.get('riskdesc', '').lower()
            count = int(alert.get('count', 1))
            if 'high' in risk: h += count
            elif 'medium' in risk: m += count
            elif 'low' in risk: l += count
            elif 'informational' in risk: pass
            else: m += count
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

run_nuclei() {
    log_info "Running Nuclei templates..."
    install_tool "nuclei" "go install -v github.com/projectdiscovery/nuclei/v3/cmd/nuclei@latest" || {
        curl -sL https://github.com/projectdiscovery/nuclei/releases/latest/download/nuclei_$(uname -s)_$(uname -m).zip -o /tmp/nuclei.zip 2>/dev/null && \
        unzip -o /tmp/nuclei.zip -d /usr/local/bin nuclei 2>/dev/null || return 0
    }

    local output_file="${REPORT_DIR}/nuclei.json"
    nuclei -u "$TARGET_URL" -jsonl -severity critical,high,medium,low -silent 2>/dev/null | \
        python3 -c "
import sys, json
results = []
for line in sys.stdin:
    line = line.strip()
    if line:
        try:
            results.append(json.loads(line))
        except:
            pass
with open('$output_file', 'w') as f:
    json.dump(results, f, indent=2)
" 2>/dev/null || true

    parse_nuclei_results
}

parse_nuclei_results() {
    local result_file="${REPORT_DIR}/nuclei.json"
    if [[ -f "$result_file" ]]; then
        local counts
        counts=$(python3 -c "
import json
try:
    with open('$result_file') as f:
        data = json.load(f)
    c = h = m = l = 0
    for item in data:
        sev = item.get('info', {}).get('severity', '').lower()
        if sev == 'critical': c += 1
        elif sev == 'high': h += 1
        elif sev == 'medium': m += 1
        elif sev == 'low': l += 1
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

run_httpx() {
    log_info "Running httpx probe..."
    install_tool "httpx" "go install -v github.com/projectdiscovery/httpx/cmd/httpx@latest" || {
        curl -sL https://github.com/projectdiscovery/httpx/releases/latest/download/httpx_$(uname -s)_$(uname -m).zip -o /tmp/httpx.zip 2>/dev/null && \
        unzip -o /tmp/httpx.zip -d /usr/local/bin httpx 2>/dev/null || return 0
    }

    echo "$TARGET_URL" | httpx -json -title -tech-detect -status-code -follow-redirects -silent 2>/dev/null > "${REPORT_DIR}/httpx.json" || true
    log_info "HTTP probe results saved"
}

run_spider() {
    log_info "Running web spider..."
    install_tool "gospider" "go install -v github.com/jaeles-project/gospider@latest" || return 0

    gospider -s "$TARGET_URL" -d 3 --other-source --json -q 2>/dev/null > "${REPORT_DIR}/spider.json" || true
    local url_count
    url_count=$(wc -l < "${REPORT_DIR}/spider.json" 2>/dev/null || echo "0")
    log_info "Spider found ${url_count} URLs"
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
    log_info "=== [iDevOps] DAST Scanner ==="

    if [[ -z "$TARGET_URL" ]]; then
        log_error "TARGET_URL not set"
        exit 1
    fi

    log_info "Target: ${TARGET_URL}"

    run_zap_scan
    run_nuclei
    run_httpx
    run_spider

    local total=$((TOTAL_CRITICAL + TOTAL_HIGH + TOTAL_MEDIUM + TOTAL_LOW))
    log_info "=== [iDevOps] DAST Scan Complete ==="
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
