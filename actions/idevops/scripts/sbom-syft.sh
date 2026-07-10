#!/usr/bin/env bash
set -euo pipefail

PREFIX="[iDevOps]"
REPORT_DIR="${IDEVOPS_REPORT_DIR:-.}"
FORMAT="${IDEVOPS_SBOM_SYFT_FORMAT:-cyclonedx-json}"

log_info() {
  echo "${PREFIX} $1"
}

log_error() {
  echo "${PREFIX} [ERROR] $1" >&2
}

cleanup() {
  local exit_code=$?
  if [[ $exit_code -ne 0 ]]; then
    log_error "Script exited with code $exit_code (continuing)"
  fi
  exit 0
}

trap cleanup EXIT

echo "::group::Installing Syft"

if command -v syft &>/dev/null; then
  log_info "Syft already installed: $(syft version 2>/dev/null || echo 'unknown version')"
else
  log_info "Installing Syft..."
  if curl -sSfL https://raw.githubusercontent.com/anchore/syft/main/install.sh | sh -s -- -b /usr/local/bin; then
    log_info "Syft installed successfully"
  else
    log_error "Failed to install Syft"
    echo "::endgroup::"
    exit 0
  fi
fi

echo "::endgroup::"

echo "::group::Generating SBOM with Syft"

OUTPUT_FILE="${REPORT_DIR}/sbom-syft.${FORMAT}"

log_info "Scanning current directory for dependencies"
log_info "Output format: ${FORMAT}"
log_info "Output file: ${OUTPUT_FILE}"

mkdir -p "${REPORT_DIR}"

if syft scan dir:. -o "${FORMAT}=${OUTPUT_FILE}" 2>/tmp/sbom-syft-err.log; then
  log_info "SBOM generated successfully: ${OUTPUT_FILE}"
else
  log_error "Syft scan failed:"
  cat /tmp/sbom-syft-err.log >&2 || true
  rm -f /tmp/sbom-syft-err.log
  echo "::endgroup::"
  exit 0
fi

rm -f /tmp/sbom-syft-err.log

echo "::endgroup::"

echo "::group::Trivy Comparison (if available)"

if command -v trivy &>/dev/null; then
  TRIVY_OUTPUT="${REPORT_DIR}/sbom-trivy-comparison.${FORMAT}"

  log_info "Running Trivy for comparison"
  log_info "Trivy output: ${TRIVY_OUTPUT}"

  if trivy fs --format cyclonedx --output "${TRIVY_OUTPUT}" . 2>/tmp/sbom-trivy-err.log; then
    log_info "Trivy SBOM generated for comparison: ${TRIVY_OUTPUT}"

    if command -v diff &>/dev/null; then
      log_info "Comparing Syft and Trivy outputs"
      log_info "Note: Full binary comparison is not meaningful - review both files manually"
    fi
  else
    log_error "Trivy scan failed (non-critical):"
    cat /tmp/sbom-trivy-err.log >&2 || true
    rm -f /tmp/sbom-trivy-err.log
  fi
else
  log_info "Trivy not available - skipping comparison"
fi

echo "::endgroup::"

echo "::group::Results Summary"

log_info "SBOM generation completed"
log_info "Primary SBOM: ${OUTPUT_FILE}"
if [[ -f "${REPORT_DIR}/sbom-trivy-comparison.${FORMAT}" ]]; then
  log_info "Trivy comparison SBOM: ${REPORT_DIR}/sbom-trivy-comparison.${FORMAT}"
fi
log_info "All SBOMs are informational - review for dependency compliance"

echo "::endgroup::"
