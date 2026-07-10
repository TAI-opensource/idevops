#!/usr/bin/env bash
# [iDevOps] SBOM Generator - CycloneDX and SPDX via Syft
set -euo pipefail

SBOM_FORMAT="${SBOM_FORMAT:-both}"
SBOM_OUTPUT_DIR="${SBOM_OUTPUT_DIR:-.}"
SBOM_TARGET="${SBOM_TARGET:-.}"
DOCKER_IMAGE="${DOCKER_IMAGE:-}"
TIMESTAMP=$(date +%Y%m%dT%H%M%SZ)

log() { echo "[iDevOps] $*"; }
warn() { echo "[iDevOps] WARNING: $*" >&2; }
err() { echo "[iDevOps] ERROR: $*" >&2; }

# --- Ensure Syft ---
ensure_syft() {
  if command -v syft &>/dev/null; then
    log "Syft found: $(syft version 2>/dev/null | head -1)"
    return
  fi

  log "Installing Syft..."
  curl -sSfL https://raw.githubusercontent.com/anchore/syft/main/install.sh | sh -s -- -b /usr/local/bin 2>/dev/null

  if ! command -v syft &>/dev/null; then
    err "Failed to install Syft"
    exit 1
  fi

  log "Syft installed: $(syft version 2>/dev/null | head -1)"
}

# --- Validate format ---
validate_format() {
  case "${SBOM_FORMAT,,}" in
    cyclonedx|spdx|both) return 0 ;;
    *) err "Invalid SBOM_FORMAT: $SBOM_FORMAT (use: cyclonedx, spdx, both)"; exit 1 ;;
  esac
}

# --- Generate SBOM ---
generate_sbom() {
  local target="$1"
  local output_dir="$2"
  local source_type="$3" # file, directory, or image

  mkdir -p "$output_dir"

  local target_label
  if [[ "$source_type" == "image" ]]; then
    target_label=$(echo "$target" | tr '/:' '__')
  else
    target_label=$(basename "$(realpath "$target")" 2>/dev/null || echo "project")
  fi

  local base_name="${output_dir}/${target_label}-${TIMESTAMP}"

  if [[ "$SBOM_FORMAT" == "cyclonedx" ]] || [[ "$SBOM_FORMAT" == "both" ]]; then
    log "Generating CycloneDX SBOM..."
    local cdx_file="${base_name}.cdx.json"
    syft "$target" -o cyclonedx-json="$cdx_file" 2>/dev/null
    if [[ -f "$cdx_file" ]]; then
      local cdx_size
      cdx_size=$(wc -c < "$cdx_file")
      log "CycloneDX SBOM: $cdx_file ($cdx_size bytes)"
    else
      warn "Failed to generate CycloneDX SBOM"
    fi
  fi

  if [[ "$SBOM_FORMAT" == "spdx" ]] || [[ "$SBOM_FORMAT" == "both" ]]; then
    log "Generating SPDX SBOM..."
    local spdx_file="${base_name}.spdx.json"
    syft "$target" -o spdx-json="$spdx_file" 2>/dev/null
    if [[ -f "$spdx_file" ]]; then
      local spdx_size
      spdx_size=$(wc -c < "$spdx_file")
      log "SPDX SBOM: $spdx_file ($spdx_size bytes)"
    else
      warn "Failed to generate SPDX SBOM"
    fi
  fi
}

# --- Main ---
main() {
  log "=========================================="
  log "[iDevOps] SBOM Generator"
  log "=========================================="
  log "Format: $SBOM_FORMAT | Output: $SBOM_OUTPUT_DIR"
  log ""

  validate_format
  ensure_syft

  mkdir -p "$SBOM_OUTPUT_DIR"

  if [[ -n "$DOCKER_IMAGE" ]]; then
    # Docker image mode
    log "Scanning Docker image: $DOCKER_IMAGE"
    generate_sbom "$DOCKER_IMAGE" "$SBOM_OUTPUT_DIR" "image"
  elif [[ -f "$SBOM_TARGET/Dockerfile" ]] || [[ -f "$SBOM_TARGET/docker-compose.yml" ]]; then
    # If Dockerfile present, try to build and scan
    log "Dockerfile detected in $SBOM_TARGET"
    log "Scanning directory: $SBOM_TARGET"
    generate_sbom "$SBOM_TARGET" "$SBOM_OUTPUT_DIR" "directory"
  else
    # Filesystem mode
    log "Scanning directory: $SBOM_TARGET"
    generate_sbom "$SBOM_TARGET" "$SBOM_OUTPUT_DIR" "directory"
  fi

  # Summary
  log ""
  log "=========================================="
  log "[iDevOps] SBOM generation complete"
  log "Output directory: $SBOM_OUTPUT_DIR"
  ls -la "$SBOM_OUTPUT_DIR"/*-"$TIMESTAMP".* 2>/dev/null || true
  log "=========================================="
}

main "$@"
