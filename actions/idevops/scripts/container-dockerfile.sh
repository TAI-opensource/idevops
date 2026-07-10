#!/usr/bin/env bash
# [iDevOps] Dockerfile Security Scanner
# Scans Dockerfiles with Hadolint + Dockle + Checkov
set -euo pipefail

SCAN_DIR="${1:-.}"
REPORT_DIR="${2:-./container-reports}"
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

run_hadolint() {
    log_info "Running Hadolint..."
    local arch
    arch=$(uname -m)
    case "$arch" in
        x86_64)  arch="x86_64" ;;
        aarch64) arch="arm64" ;;
        armv7l)  arch="armv7" ;;
    esac
    install_tool "hadolint" "curl -sL https://github.com/hadolint/hadolint/releases/latest/download/hadolint-Linux-${arch} -o /usr/local/bin/hadolint && chmod +x /usr/local/bin/hadolint" || return 0

    local all_findings=0
    find "$SCAN_DIR" \( -name "Dockerfile*" -o -name "*.dockerfile" \) | while read -r dockerfile; do
        log_info "Scanning ${dockerfile}..."

        local output_file="${REPORT_DIR}/hadolint-$(basename "$dockerfile").json"
        hadolint --format json "$dockerfile" > "$output_file" 2>&1 || true

        local findings
        findings=$(python3 -c "
import json
try:
    with open('$output_file') as f:
        data = json.load(f)
    c = h = m = l = 0
    for item in data:
        level = item.get('level', '').upper()
        if level == 'error': c += 1
        elif level == 'warning': m += 1
        elif level == 'info': l += 1
    print(f'{c} {h} {m} {l}')
except:
    print('0 0 0 0')
" 2>/dev/null || echo "0 0 0 0")
        local c h m l
        read -r c h m l <<< "$findings"
        TOTAL_CRITICAL=$((TOTAL_CRITICAL + c))
        TOTAL_MEDIUM=$((TOTAL_MEDIUM + m))
        TOTAL_LOW=$((TOTAL_LOW + l))

        if [[ "$OUTPUT_FORMAT" == "sarif" ]]; then
            python3 -c "
import json
try:
    with open('$output_file') as f:
        data = json.load(f)
    sarif = {
        '\$schema': 'https://raw.githubusercontent.com/oasis-tcs/sarif-spec/main/sarif-2.1/schema/sarif-schema-2.1.0.json',
        'version': '2.1.0',
        'runs': [{
            'tool': {'driver': {'name': 'hadolint', 'version': 'latest'}},
            'results': [{
                'ruleId': r.get('code', ''),
                'message': {'text': r.get('message', '')},
                'level': 'error' if r.get('level') == 'error' else 'warning',
                'locations': [{'physicalLocation': {'artifactLocation': {'uri': r.get('file', '')}, 'region': {'startLine': r.get('line', 0)}}}]
            } for r in data]
        }]
    }
    with open('${REPORT_DIR}/hadolint.sarif', 'w') as f:
        json.dump(sarif, f, indent=2)
except:
    pass
" 2>/dev/null || true
        fi
    done
}

run_dockle() {
    log_info "Running Dockle..."
    local arch
    arch=$(uname -m)
    case "$arch" in
        x86_64)  arch="x86_64" ;;
        aarch64) arch="arm64" ;;
        armv7l)  arch="armv7" ;;
    esac
    install_tool "dockle" "curl -sL https://github.com/goodwithtech/dockle/releases/latest/download/dockle_Linux_${arch}.tar.gz | tar xz -C /usr/local/bin dockle" || return 0

    local image_tag="${CONTAINER_IMAGE:-}"
    if [[ -z "$image_tag" ]]; then
        find "$SCAN_DIR" \( -name "Dockerfile*" -o -name "*.dockerfile" \) | while read -r dockerfile; do
            log_info "Building temporary image from ${dockerfile} for Dockle scan..."
            local tmp_image="idevops-scan-$(echo "$dockerfile" | md5sum | cut -c1-8)"
            docker build -t "$tmp_image" -f "$dockerfile" "$(dirname "$dockerfile")" 2>/dev/null || true

            if docker image inspect "$tmp_image" &>/dev/null; then
                local output_file="${REPORT_DIR}/dockle-$(basename "$dockerfile").json"
                dockle -f json -o "$output_file" "$tmp_image" 2>&1 || true

                local findings
                findings=$(python3 -c "
import json
try:
    with open('$output_file') as f:
        data = json.load(f)
    c = h = m = l = 0
    for item in data.get('alerts', []):
        level = item.get('level', '').upper()
        if level == 'FATAL': c += 1
        elif level == 'WARN': m += 1
        elif level == 'INFO': l += 1
    print(f'{c} {h} {m} {l}')
except:
    print('0 0 0 0')
" 2>/dev/null || echo "0 0 0 0")
                local c h m l
                read -r c h m l <<< "$findings"
                TOTAL_CRITICAL=$((TOTAL_CRITICAL + c))
                TOTAL_MEDIUM=$((TOTAL_MEDIUM + m))
                TOTAL_LOW=$((TOTAL_LOW + l))

                docker rmi "$tmp_image" 2>/dev/null || true
            fi
        done
    else
        local output_file="${REPORT_DIR}/dockle.json"
        dockle -f json -o "$output_file" "$image_tag" 2>&1 || true
    fi
}

run_checkov_docker() {
    log_info "Running Checkov (Docker)..."
    install_tool "checkov" "pip3 install checkov" || return 0

    local checkov_args=(-d "$SCAN_DIR" --framework dockerfile --compact)
    if [[ "$OUTPUT_FORMAT" == "sarif" ]]; then
        checkov_args+=(--output sarif --output-file "${REPORT_DIR}/checkov-docker.sarif")
    elif [[ "$OUTPUT_FORMAT" == "json" ]]; then
        checkov_args+=(--output json --output-file "${REPORT_DIR}/checkov-docker.json")
    fi

    checkov "${checkov_args[@]}" 2>&1 || true

    local result_file="${REPORT_DIR}/checkov-docker.json"
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
    log_info "=== [iDevOps] Dockerfile Scanner ==="

    local dockerfiles
    dockerfiles=$(find "$SCAN_DIR" \( -name "Dockerfile*" -o -name "*.dockerfile" \) 2>/dev/null)

    if [[ -z "$dockerfiles" ]]; then
        log_warn "No Dockerfiles found in ${SCAN_DIR}"
        exit 0
    fi

    run_hadolint
    run_dockle
    run_checkov_docker

    local total=$((TOTAL_CRITICAL + TOTAL_HIGH + TOTAL_MEDIUM + TOTAL_LOW))
    log_info "=== [iDevOps] Dockerfile Scan Complete ==="
    log_info "Findings: ${total} (Critical: ${TOTAL_CRITICAL}, High: ${TOTAL_HIGH}, Medium: ${TOTAL_MEDIUM}, Low: ${TOTAL_LOW})"

    if should_fail "$FAIL_ON"; then
        log_error "FAILED: Findings exceed ${FAIL_ON} threshold"
        exit 1
    fi

    log_success "PASSED"
    exit 0
}

main "$@"
