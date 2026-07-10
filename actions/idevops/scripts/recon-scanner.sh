#!/usr/bin/env bash
# [iDevOps] Security Reconnaissance Scanner
# Nuclei + httpx + subfinder + naabu for comprehensive recon
set -euo pipefail

TARGET="${TARGET:-}"
TARGET_URL="${TARGET_URL:-}"
SCAN_DIR="${SCAN_DIR:-.}"
FAIL_ON="${FAIL_ON:-HIGH}"
REPORT_DIR="${REPORT_DIR:-./recon-reports}"
TIMEOUT="${TIMEOUT:-600}"
PORTS="${PORTS:-top-1000}"

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
TARGETS_FOUND=""

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

extract_domain() {
    local url="$1"
    echo "$url" | sed -E 's|^https?://||; s|/.*||; s|:.*||'
}

extract_urls_from_repo() {
    log_info "Extracting URLs from repository..."
    local urls_file="${REPORT_DIR}/repo-urls.txt"
    > "$urls_file"

    find "$SCAN_DIR" \( -name "*.md" -o -name "*.txt" -o -name "*.yaml" -o -name "*.yml" -o -name "*.json" -o -name "*.env" -o -name "*.conf" -o -name "*.cfg" -o -name "*.ini" -o -name "*.py" -o -name "*.js" -o -name "*.ts" -o -name "*.go" -o -name "*.rb" -o -name "*.java" \) 2>/dev/null | \
        xargs grep -ohE 'https?://[a-zA-Z0-9._/~:?#@!$&'"'"'()+=%-]+' 2>/dev/null | \
        sort -u > "$urls_file" || true

    local url_count
    url_count=$(wc -l < "$urls_file" 2>/dev/null || echo "0")
    log_info "Found ${url_count} unique URLs in repository"

    if [[ "$url_count" -gt 0 ]]; then
        TARGET_URL=$(head -1 "$urls_file")
        TARGET=$(extract_domain "$TARGET_URL")
        TARGETS_FOUND="yes"
    fi
}

run_subfinder() {
    log_info "Running subfinder for subdomain enumeration..."
    install_tool "subfinder" "go install -v github.com/projectdiscovery/subfinder/v3/cmd/subfinder@latest" || {
        curl -sL https://github.com/projectdiscovery/subfinder/releases/latest/download/subfinder_$(uname -s)_$(uname -m).zip -o /tmp/subfinder.zip 2>/dev/null && \
        unzip -o /tmp/subfinder.zip -d /usr/local/bin subfinder 2>/dev/null || return 0
    }

    local output_file="${REPORT_DIR}/subdomains.txt"
    subfinder -d "$TARGET" -silent -o "$output_file" 2>/dev/null || true

    local sub_count
    sub_count=$(wc -l < "$output_file" 2>/dev/null || echo "0")
    log_info "Found ${sub_count} subdomains"

    if [[ "$sub_count" -gt 0 ]] && [[ -z "$TARGET_URL" ]]; then
        TARGET_URL="http://$(head -1 "$output_file")"
    fi
}

run_naabu() {
    log_info "Running naabu port scan..."
    install_tool "naabu" "go install -v github.com/projectdiscovery/naabu/v2/cmd/naabu@latest" || {
        curl -sL https://github.com/projectdiscovery/naabu/releases/latest/download/naabu_$(uname -s)_$(uname -m).zip -o /tmp/naabu.zip 2>/dev/null && \
        unzip -o /tmp/naabu.zip -d /usr/local/bin naabu 2>/dev/null || return 0
    }

    local output_file="${REPORT_DIR}/ports.txt"
    local hosts=("$TARGET")

    if [[ -f "${REPORT_DIR}/subdomains.txt" ]]; then
        while IFS= read -r sub; do
            [[ -n "$sub" ]] && hosts+=("$sub")
        done < "${REPORT_DIR}/subdomains.txt"
    fi

    printf '%s\n' "${hosts[@]}" | naabu -silent -c "$PORTS" -o "$output_file" 2>/dev/null || true

    local port_count
    port_count=$(wc -l < "$output_file" 2>/dev/null || echo "0")
    log_info "Found ${port_count} open ports"

    if [[ "$port_count" -gt 0 ]]; then
        ((TOTAL_LOW++)) || true
    fi
}

run_httpx_probe() {
    log_info "Running httpx HTTP probe..."
    install_tool "httpx" "go install -v github.com/projectdiscovery/httpx/cmd/httpx@latest" || return 0

    local urls_file="${REPORT_DIR}/httpx-urls.txt"
    > "$urls_file"

    if [[ -f "${REPORT_DIR}/subdomains.txt" ]]; then
        while IFS= read -r sub; do
            [[ -n "$sub" ]] && echo "http://${sub}" >> "$urls_file"
            [[ -n "$sub" ]] && echo "https://${sub}" >> "$urls_file"
        done < "${REPORT_DIR}/subdomains.txt"
    fi

    if [[ -f "${REPORT_DIR}/ports.txt" ]]; then
        while IFS= read -r port_line; do
            local host port
            host=$(echo "$port_line" | cut -d: -f1)
            port=$(echo "$port_line" | cut -d: -f2)
            [[ -n "$port" ]] && echo "http://${host}:${port}" >> "$urls_file"
            [[ -n "$port" ]] && echo "https://${host}:${port}" >> "$urls_file"
        done < "${REPORT_DIR}/ports.txt"
    fi

    if [[ -f "${REPORT_DIR}/repo-urls.txt" ]]; then
        cat "${REPORT_DIR}/repo-urls.txt" >> "$urls_file"
    fi

    local output_file="${REPORT_DIR}/httpx-results.json"
    sort -u "$urls_file" | httpx -json -title -tech-detect -status-code -follow-redirects -silent 2>/dev/null > "$output_file" || true

    local live_count
    live_count=$(wc -l < "$output_file" 2>/dev/null || echo "0")
    log_info "Found ${live_count} live HTTP services"
}

run_nuclei_scan() {
    log_info "Running Nuclei vulnerability scan..."
    install_tool "nuclei" "go install -v github.com/projectdiscovery/nuclei/v3/cmd/nuclei@latest" || return 0

    local output_file="${REPORT_DIR}/nuclei.json"
    local targets_file="${REPORT_DIR}/nuclei-targets.txt"
    > "$targets_file"

    if [[ -f "${REPORT_DIR}/repo-urls.txt" ]]; then
        cat "${REPORT_DIR}/repo-urls.txt" >> "$targets_file"
    fi

    if [[ -f "${REPORT_DIR}/subdomains.txt" ]]; then
        while IFS= read -r sub; do
            [[ -n "$sub" ]] && echo "http://${sub}" >> "$targets_file"
            [[ -n "$sub" ]] && echo "https://${sub}" >> "$targets_file"
        done < "${REPORT_DIR}/subdomains.txt"
    fi

    if [[ -f "${REPORT_DIR}/ports.txt" ]]; then
        while IFS= read -r port_line; do
            local host port
            host=$(echo "$port_line" | cut -d: -f1)
            port=$(echo "$port_line" | cut -d: -f2)
            [[ -n "$port" ]] && echo "http://${host}:${port}" >> "$targets_file"
            [[ -n "$port" ]] && echo "https://${host}:${port}" >> "$targets_file"
        done < "${REPORT_DIR}/ports.txt"
    fi

    local target_count
    target_count=$(wc -l < "$targets_file" 2>/dev/null || echo "0")

    if [[ "$target_count" -gt 0 ]]; then
        sort -u "$targets_file" | nuclei -jsonl -severity critical,high,medium,low -silent 2>/dev/null | \
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
    fi

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

generate_summary() {
    log_info "Generating recon summary..."

    local summary_file="${REPORT_DIR}/recon-summary.json"
    python3 -c "
import json

summary = {
    'target': '${TARGET}',
    'target_url': '${TARGET_URL}',
    'subdomains_file': '${REPORT_DIR}/subdomains.txt',
    'ports_file': '${REPORT_DIR}/ports.txt',
    'httpx_file': '${REPORT_DIR}/httpx-results.json',
    'nuclei_file': '${REPORT_DIR}/nuclei.json',
    'repo_urls_file': '${REPORT_DIR}/repo-urls.txt',
    'findings': {
        'critical': ${TOTAL_CRITICAL},
        'high': ${TOTAL_HIGH},
        'medium': ${TOTAL_MEDIUM},
        'low': ${TOTAL_LOW}
    }
}

with open('$summary_file', 'w') as f:
    json.dump(summary, f, indent=2)
" 2>/dev/null || true
    log_info "Summary saved to ${summary_file}"
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
    log_info "=== [iDevOps] Recon Scanner ==="

    if [[ -z "$TARGET" ]] && [[ -z "$TARGET_URL" ]]; then
        extract_urls_from_repo
    fi

    if [[ -z "$TARGET" ]] && [[ -z "$TARGET_URL" ]]; then
        log_warn "No target specified and no URLs found in repository"
        exit 0
    fi

    [[ -n "$TARGET_URL" ]] && TARGET=$(extract_domain "$TARGET_URL")

    log_info "Target: ${TARGET:-unknown}"
    log_info "URL: ${TARGET_URL:-not set}"

    run_subfinder
    run_naabu
    run_httpx_probe
    run_nuclei_scan
    generate_summary

    local total=$((TOTAL_CRITICAL + TOTAL_HIGH + TOTAL_MEDIUM + TOTAL_LOW))
    log_info "=== [iDevOps] Recon Scan Complete ==="
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
