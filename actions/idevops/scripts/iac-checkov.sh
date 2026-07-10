#!/usr/bin/env bash
# [iDevOps] Checkov IaC Scanner
# Multi-framework IaC security scanning via Checkov (Terraform, CloudFormation,
# Kubernetes, Helm, Dockerfile, Ansible)
set -euo pipefail

SCAN_DIR="${SCAN_DIR:-.}"
REPORT_DIR="${IDEVOPS_REPORT_DIR:-./iac-reports}"
FRAMEWORKS="${IDEVOPS_CHECKOV_FRAMEWORKS:-terraform,cloudformation,kubernetes,helm,dockerfile,ansible}"

log_info()    { echo "[iDevOps] $*"; }
log_warn()    { echo "[iDevOps] WARNING: $*"; }
log_error()   { echo "[iDevOps] ERROR: $*"; }

mkdir -p "${REPORT_DIR}"

# ---------------------------------------------------------------------------
# Detect which requested frameworks actually have files in the scan directory
# ---------------------------------------------------------------------------
detect_active_frameworks() {
    local active=""
    local IFS=','
    read -ra fw_list <<< "$FRAMEWORKS"

    for fw in "${fw_list[@]}"; do
        fw=$(echo "$fw" | xargs) # trim whitespace
        case "$fw" in
            terraform)
                if find "$SCAN_DIR" -name '*.tf' -o -name '*.tfvars' 2>/dev/null | head -1 | grep -q .; then
                    active="${active:+${active},}terraform"
                fi
                ;;
            cloudformation)
                if find "$SCAN_DIR" \( -name '*.yaml' -o -name '*.yml' -o -name '*.json' \) \
                    -exec grep -l 'AWSTemplateFormatVersion' {} \; 2>/dev/null | head -1 | grep -q .; then
                    active="${active:+${active},}cloudformation"
                fi
                ;;
            kubernetes)
                if find "$SCAN_DIR" \( -name '*.yaml' -o -name '*.yml' \) \
                    -exec grep -l 'apiVersion:' {} \; 2>/dev/null | head -1 | grep -q .; then
                    active="${active:+${active},}kubernetes"
                fi
                ;;
            helm)
                if find "$SCAN_DIR" -name 'Chart.yaml' 2>/dev/null | head -1 | grep -q .; then
                    active="${active:+${active},}kubernetes"
                fi
                ;;
            dockerfile|docker)
                if find "$SCAN_DIR" -name 'Dockerfile*' -o -name '*.dockerfile' 2>/dev/null | head -1 | grep -q .; then
                    active="${active:+${active},}dockerfile"
                fi
                ;;
            ansible)
                if find "$SCAN_DIR" \( -name '*.yaml' -o -name '*.yml' \) \
                    -exec grep -l 'tasks:' {} \; 2>/dev/null | head -1 | grep -q .; then
                    active="${active:+${active},}ansible"
                fi
                ;;
        esac
    done

    echo "$active"
}

# ---------------------------------------------------------------------------
# Ensure checkov is available
# ---------------------------------------------------------------------------
ensure_checkov() {
    if command -v checkov &>/dev/null; then
        return 0
    fi

    log_info "Installing checkov..."
    if pip install checkov >/dev/null 2>&1; then
        log_info "checkov installed successfully"
        return 0
    fi

    log_error "Failed to install checkov"
    return 1
}

# ---------------------------------------------------------------------------
# Build the checkov argument list
# ---------------------------------------------------------------------------
build_checkov_args() {
    local active="$1"
    local args=(-d "$SCAN_DIR" --compact --quiet)

    local IFS=','
    read -ra fw_list <<< "$active"
    for fw in "${fw_list[@]}"; do
        fw=$(echo "$fw" | xargs)
        args+=(--framework "$fw")
    done

    # Prefer SARIF output; fall back to JUnit XML
    if checkov --help 2>&1 | grep -q '\-\-output sarif'; then
        args+=(--output sarif --output-file "${REPORT_DIR}/checkov.sarif")
    else
        args+=(--output junitxml --output-file "${REPORT_DIR}/checkov-results.xml")
    fi

    echo "${args[@]}"
}

# ---------------------------------------------------------------------------
# Parse results if a JSON intermediate is available (best-effort)
# ---------------------------------------------------------------------------
parse_results() {
    local sarif_file="${REPORT_DIR}/checkov.sarif"
    local xml_file="${REPORT_DIR}/checkov-results.xml"

    if [[ -f "$sarif_file" ]]; then
        log_info "SARIF report saved to ${sarif_file}"
    elif [[ -f "$xml_file" ]]; then
        log_info "JUnit XML report saved to ${xml_file}"
    fi
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
main() {
    log_info "=== [iDevOps] Checkov IaC Scanner ==="
    log_info "Scan directory: ${SCAN_DIR}"
    log_info "Requested frameworks: ${FRAMEWORKS}"

    echo "::group::Detecting IaC files"
    local active
    active=$(detect_active_frameworks)
    echo "::endgroup::"

    if [[ -z "$active" ]]; then
        log_info "No IaC files detected for any requested framework - skipping scan"
        exit 0
    fi

    log_info "Active frameworks: ${active}"

    echo "::group::Installing checkov"
    if ! ensure_checkov; then
        log_error "Cannot proceed without checkov"
        exit 0
    fi
    echo "::endgroup::"

    echo "::group::Running checkov scan"
    local -a checkov_args
    read -ra checkov_args <<< "$(build_checkov_args "$active")"

    local exit_code=0
    checkov "${checkov_args[@]}" 2>&1 || exit_code=$?
    echo "::endgroup::"

    echo "::group::Processing results"
    parse_results
    echo "::endgroup::"

    log_info "=== [iDevOps] Checkov scan complete ==="

    if [[ $exit_code -ne 0 ]]; then
        log_warn "Checkov exited with code ${exit_code} (findings may exist)"
    fi

    # Always exit 0 for continue-on-error compatibility
    exit 0
}

main "$@"
