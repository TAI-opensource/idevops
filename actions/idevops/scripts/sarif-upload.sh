#!/usr/bin/env bash
# SARIF upload to GitHub Code Scanning API
# Replaces github/codeql-action/upload-sarif
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Inputs via env vars
SARIF_FILE="${SARIF_FILE:-}"
SARIF_FILES="${SARIF_FILES:-}"
GITHUB_TOKEN="${GITHUB_TOKEN:-}"
REPOSITORY="${GITHUB_REPOSITORY:-}"
COMMIT_SHA="${GITHUB_SHA:-}"
REF="${GITHUB_REF:-}"
WORKFLOW_NAME="${GITHUB_WORKFLOW:-}"
CHECK_RUN_ID="${GITHUB_RUN_ID:-}"

echo "[iDevOps] SARIF Upload to GitHub Code Scanning"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Validate inputs
if [ -z "$GITHUB_TOKEN" ]; then
  echo "[iDevOps] ERROR: GITHUB_TOKEN is required"
  exit 1
fi

if [ -z "$REPOSITORY" ]; then
  echo "[iDevOps] ERROR: GITHUB_REPOSITORY is required"
  exit 1
fi

# Collect SARIF files to upload
UPLOAD_FILES=()
if [ -n "$SARIF_FILE" ] && [ -f "$SARIF_FILE" ]; then
  UPLOAD_FILES+=("$SARIF_FILE")
fi

if [ -n "$SARIF_FILES" ]; then
  IFS=',' read -ra FILE_ARRAY <<< "$SARIF_FILES"
  for f in "${FILE_ARRAY[@]}"; do
    f=$(echo "$f" | xargs)  # trim whitespace
    if [ -f "$f" ]; then
      UPLOAD_FILES+=("$f")
    fi
  done
fi

# Also check for any .sarif files in the reports directory
REPORT_DIR="${REPORT_DIR:-.idevops/reports}"
if [ -d "$REPORT_DIR" ]; then
  while IFS= read -r -d '' sarif; do
    UPLOAD_FILES+=("$sarif")
  done < <(find "$REPORT_DIR" -name "*.sarif" -type f -print0 2>/dev/null)
fi

if [ ${#UPLOAD_FILES[@]} -eq 0 ]; then
  echo "[iDevOps] No SARIF files found to upload"
  exit 0
fi

echo "[iDevOps] Found ${#UPLOAD_FILES[@]} SARIF file(s) to upload"

# Deduplicate
UNIQUE_FILES=($(printf '%s\n' "${UPLOAD_FILES[@]}" | sort -u))

# Upload each SARIF file
UPLOADED=0
FAILED=0

for sarif in "${UNIQUE_FILES[@]}"; do
  echo "[iDevOps] Uploading: $sarif"

  # Validate SARIF is valid JSON
  if ! jq empty "$sarif" 2>/dev/null; then
    echo "[iDevOps] WARNING: $sarif is not valid JSON, skipping"
    FAILED=$((FAILED + 1))
    continue
  fi

  # Generate commit SHA for the SARIF
  if [ -n "$COMMIT_SHA" ]; then
    FINAL_SHA="$COMMIT_SHA"
  else
    FINAL_SHA=$(git rev-parse HEAD 2>/dev/null || echo "unknown")
  fi

  # Build the request body
  BODY=$(jq -n \
    --arg sarif "$(cat "$sarif")" \
    --arg commit_sha "$FINAL_SHA" \
    --arg ref "$REF" \
    --arg workflow "$WORKFLOW_NAME" \
    '{
      sarif: $sarif,
      commit_sha: $commit_sha,
      ref: $ref,
      validate: true
    }')

  # Upload to GitHub API
  RESPONSE=$(curl -s -w "\n%{http_code}" \
    -X POST \
    -H "Authorization: token $GITHUB_TOKEN" \
    -H "Accept: application/vnd.github+json" \
    -H "User-Agent: iDevOps-Actions" \
    -d "$BODY" \
    "https://api.github.com/repos/${REPOSITORY}/code-scanning/sarifs" 2>&1)

  HTTP_STATUS=$(echo "$RESPONSE" | tail -1)
  RESPONSE_BODY=$(echo "$RESPONSE" | sed '$d')

  if [ "$HTTP_STATUS" -ge 200 ] && [ "$HTTP_STATUS" -lt 300 ]; then
    SARIF_ID=$(echo "$RESPONSE_BODY" | jq -r '.id // "unknown"' 2>/dev/null)
    echo "[iDevOps] OK: $sarif uploaded (ID: $SARIF_ID)"
    UPLOADED=$((UPLOADED + 1))
  elif [ "$HTTP_STATUS" -eq 403 ]; then
    echo "[iDevOps] WARNING: Permission denied for $sarif (need security-events: write)"
    FAILED=$((FAILED + 1))
  elif [ "$HTTP_STATUS" -eq 422 ]; then
    echo "[iDevOps] WARNING: Validation failed for $sarif"
    echo "$RESPONSE_BODY" | jq '.errors' 2>/dev/null || echo "$RESPONSE_BODY"
    FAILED=$((FAILED + 1))
  else
    echo "[iDevOps] ERROR: Failed to upload $sarif (HTTP $HTTP_STATUS)"
    echo "$RESPONSE_BODY" | jq '.' 2>/dev/null || echo "$RESPONSE_BODY"
    FAILED=$((FAILED + 1))
  fi
done

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "[iDevOps] SARIF Upload Summary"
echo "  Uploaded: $UPLOADED"
echo "  Failed:   $FAILED"
echo "  Total:    ${#UNIQUE_FILES[@]}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [ "$UPLOADED" -eq 0 ] && [ "$FAILED" -gt 0 ]; then
  exit 1
fi
