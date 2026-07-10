#!/usr/bin/env bash
# iDevOps - Universal Security Scanner
# Auto-detects languages and runs appropriate security tools
# Categories: sast, sca, secrets, container, iac
set -euo pipefail

# ============================================================================
# Configuration
# ============================================================================
FAIL_ON="${FAIL_ON:-high}"
LANGUAGES="${LANGUAGES:-auto}"
SCAN_CATEGORIES="${SCAN_CATEGORIES:-sast,sca,secrets,container,iac}"
SCAN_DIR="${SCAN_DIR:-.}"
OUTPUT_DIR="${OUTPUT_DIR:-./security-results}"
SARIF_MERGE="${SARIF_MERGE:-false}"

# Severity ordering for threshold comparison
# critical=4, high=3, medium=2, low=1, never=0
severity_to_num() {
  case "${1,,}" in
    critical) echo 4 ;;
    high)     echo 3 ;;
    medium)   echo 2 ;;
    low)      echo 1 ;;
    never)    echo 0 ;;
    *)        echo 3 ;;
  esac
}

FAIL_ON_NUM=$(severity_to_num "$FAIL_ON")

# Counters
TOTAL_CRITICAL=0
TOTAL_HIGH=0
TOTAL_MEDIUM=0
TOTAL_LOW=0
TOTAL_FINDINGS=0
TOOLS_RUN=0
TOOLS_SKIPPED=0
TOOLS_FAILED=0

# Collect SARIF files
SARIF_FILES=()

# ============================================================================
# Utility functions
# ============================================================================
log() {
  echo "[iDevOps] $*"
}

log_section() {
  echo ""
  echo "=========================================================="
  echo "  [iDevOps] $*"
  echo "=========================================================="
  echo ""
}

log_tool_header() {
  echo ""
  echo "--------------------------------------------------------"
  echo "  [iDevOps] $*"
  echo "--------------------------------------------------------"
}

# Count SARIF findings by severity
count_sarif() {
  local file="$1"
  if [ ! -f "$file" ]; then
    echo "0 0 0 0"
    return
  fi
  local c h m l
  c=$(grep -c '"level":"error"' "$file" 2>/dev/null || echo "0")
  h=$(grep -c '"level":"warning"' "$file" 2>/dev/null || echo "0")
  m=$(grep -c '"level":"note"' "$file" 2>/dev/null || echo "0")
  l=$(grep -c '"level":"none"' "$file" 2>/dev/null || echo "0")
  echo "$c $h $m $l"
}

# Check if a severity meets the fail threshold
should_fail() {
  local severity="$1"
  local sev_num
  sev_num=$(severity_to_num "$severity")
  [ "$sev_num" -ge "$FAIL_ON_NUM" ] && [ "$FAIL_ON_NUM" -gt 0 ]
}

# Add findings to global counters
accumulate_findings() {
  local file="$1"
  local counts
  counts=$(count_sarif "$file")
  read -r c h m l <<< "$counts"
  TOTAL_CRITICAL=$((TOTAL_CRITICAL + c))
  TOTAL_HIGH=$((TOTAL_HIGH + h))
  TOTAL_MEDIUM=$((TOTAL_MEDIUM + m))
  TOTAL_LOW=$((TOTAL_LOW + l))
  TOTAL_FINDINGS=$((TOTAL_FINDINGS + c + h + m + l))
}

# Try to install a tool, return 0 if available, 1 if not
ensure_tool() {
  local tool_name="$1"
  shift
  if command -v "$tool_name" &>/dev/null; then
    return 0
  fi
  log "Installing $tool_name..."
  # Execute the install commands passed as arguments
  if ! eval "$@" 2>/dev/null; then
    log "WARNING: Failed to install $tool_name"
    return 1
  fi
  if command -v "$tool_name" &>/dev/null; then
    log "$tool_name installed successfully"
    return 0
  fi
  log "WARNING: $tool_name not available after install"
  return 1
}

# ============================================================================
# Language Detection
# ============================================================================
detect_languages() {
  if [ "$LANGUAGES" != "auto" ]; then
    echo "$LANGUAGES"
    return
  fi

  local detected=""
  local dir="$SCAN_DIR"

  # Manifest files -> language indicators
  [ -f "$dir/package.json" ] || [ -f "$dir/yarn.lock" ] || [ -f "$dir/package-lock.json" ] || [ -f "$dir/pnpm-lock.yaml" ] && {
    detected="$detected javascript"
    # Check for TypeScript
    [ -f "$dir/tsconfig.json" ] && detected="$detected typescript"
  }
  [ -f "$dir/requirements.txt" ] || [ -f "$dir/setup.py" ] || [ -f "$dir/setup.cfg" ] || \
    [ -f "$dir/pyproject.toml" ] || [ -f "$dir/Pipfile" ] || [ -f "$dir/poetry.lock" ] && \
    detected="$detected python"
  [ -f "$dir/go.mod" ] && detected="$detected go"
  [ -f "$dir/Cargo.toml" ] && detected="$detected rust"
  [ -f "$dir/pom.xml" ] || [ -f "$dir/build.gradle" ] || [ -f "$dir/build.gradle.kts" ] || \
    [ -f "$dir/gradlew" ] || [ -f "$dir/mvnw" ] && detected="$detected java"
  [ -f "$dir/Gemfile" ] || [ -f "$dir/*.gemspec" ] || [ -f "$dir/Rakefile" ] && detected="$detected ruby"
  [ -f "$dir/composer.json" ] && detected="$detected php"
  [ -f "$dir/Cargo.lock" ] && detected="$detected rust"
  [ -f "$dir/go.sum" ] && detected="$detected go"

  # Check file extensions for additional languages
  if [ -z "$detected" ]; then
    local has_js has_py has_go has_rs has_java has_rb has_php has_ts
    has_js=$(find "$dir" -maxdepth 3 -name "*.js" -o -name "*.jsx" -o -name "*.mjs" -o -name "*.cjs" 2>/dev/null | head -1)
    has_ts=$(find "$dir" -maxdepth 3 -name "*.ts" -o -name "*.tsx" 2>/dev/null | head -1)
    has_py=$(find "$dir" -maxdepth 3 -name "*.py" 2>/dev/null | head -1)
    has_go=$(find "$dir" -maxdepth 3 -name "*.go" 2>/dev/null | head -1)
    has_rs=$(find "$dir" -maxdepth 3 -name "*.rs" 2>/dev/null | head -1)
    has_java=$(find "$dir" -maxdepth 3 -name "*.java" -o -name "*.kt" -o -name "*.scala" 2>/dev/null | head -1)
    has_rb=$(find "$dir" -maxdepth 3 -name "*.rb" 2>/dev/null | head -1)
    has_php=$(find "$dir" -maxdepth 3 -name "*.php" 2>/dev/null | head -1)

    [ -n "$has_js" ] && detected="$detected javascript"
    [ -n "$has_ts" ] && detected="$detected typescript"
    [ -n "$has_py" ] && detected="$detected python"
    [ -n "$has_go" ] && detected="$detected go"
    [ -n "$has_rs" ] && detected="$detected rust"
    [ -n "$has_java" ] && detected="$detected java"
    [ -n "$has_rb" ] && detected="$detected ruby"
    [ -n "$has_php" ] && detected="$detected php"
  fi

  # Deduplicate
  echo "$detected" | tr ' ' '\n' | sort -u | tr '\n' ' ' | sed 's/^ *//;s/ *$//'
}

# ============================================================================
# SAST Scanners
# ============================================================================
run_semgrep() {
  log_tool_header "Semgrep SAST (all languages)"

  if ! ensure_tool semgrep "pip3 install semgrep 2>/dev/null || pip install semgrep 2>/dev/null || (curl -sSL https://semgrep.dev/install.sh | sh)"; then
    TOOLS_SKIPPED=$((TOOLS_SKIPPED + 1))
    return
  fi

  local outfile="$OUTPUT_DIR/semgrep-results.sarif"
  log "Running Semgrep..."

  semgrep scan \
    --config auto \
    --sarif --output "$outfile" \
    --severity ERROR --severity WARNING \
    --jobs 4 \
    "$SCAN_DIR" 2>/dev/null || true

  if [ -s "$outfile" ]; then
    accumulate_findings "$outfile"
    SARIF_FILES+=("$outfile")
    TOOLS_RUN=$((TOOLS_RUN + 1))
    local counts
    counts=$(count_sarif "$outfile")
    read -r c h m l <<< "$counts"
    log "Semgrep findings: C=$c H=$h M=$m L=$l"
  else
    log "Semgrep: no findings"
    TOOLS_RUN=$((TOOLS_RUN + 1))
  fi
}

run_bandit() {
  log_tool_header "Bandit (Python SAST)"

  if ! echo "$DETECTED_LANGS" | grep -qi "python"; then
    log "No Python detected, skipping Bandit"
    TOOLS_SKIPPED=$((TOOLS_SKIPPED + 1))
    return
  fi

  if ! ensure_tool bandit "pip3 install bandit 2>/dev/null || pip install bandit 2>/dev/null"; then
    TOOLS_SKIPPED=$((TOOLS_SKIPPED + 1))
    return
  fi

  local outfile="$OUTPUT_DIR/bandit-results.sarif"
  log "Running Bandit..."

  # Find Python source directories
  local py_dirs=""
  while IFS= read -r d; do
    py_dirs="$py_dirs $d"
  done < <(find "$SCAN_DIR" -maxdepth 3 -name "*.py" -printf '%h\n' 2>/dev/null | sort -u | head -10)

  if [ -z "$py_dirs" ]; then
    py_dirs="$SCAN_DIR"
  fi

  bandit -r $py_dirs \
    --format sarif \
    --output "$outfile" \
    -ll 2>/dev/null || true

  if [ -s "$outfile" ]; then
    accumulate_findings "$outfile"
    SARIF_FILES+=("$outfile")
    TOOLS_RUN=$((TOOLS_RUN + 1))
    local counts
    counts=$(count_sarif "$outfile")
    read -r c h m l <<< "$counts"
    log "Bandit findings: C=$c H=$h M=$m L=$l"
  else
    log "Bandit: no findings"
    TOOLS_RUN=$((TOOLS_RUN + 1))
  fi
}

run_brakeman() {
  log_tool_header "Brakeman (Ruby SAST)"

  if ! echo "$DETECTED_LANGS" | grep -qi "ruby"; then
    log "No Ruby detected, skipping Brakeman"
    TOOLS_SKIPPED=$((TOOLS_SKIPPED + 1))
    return
  fi

  if ! ensure_tool brakeman "gem install brakeman 2>/dev/null || (curl -sSfL https://github.com/presidentbeef/brakeman/releases/latest/download/brakeman-$(curl -s https://api.github.com/repos/presidentbeef/brakeman/releases/latest | grep tag_name | cut -d\" -f4 | sed s/v//).gem -o /tmp/brakeman.gem && gem install /tmp/brakeman.gem 2>/dev/null)"; then
    TOOLS_SKIPPED=$((TOOLS_SKIPPED + 1))
    return
  fi

  local outfile="$OUTPUT_DIR/brakeman-results.sarif"
  log "Running Brakeman..."

  brakeman \
    --no-pager \
    --format sarif \
    --output "$outfile" \
    "$SCAN_DIR" 2>/dev/null || true

  if [ -s "$outfile" ]; then
    accumulate_findings "$outfile"
    SARIF_FILES+=("$outfile")
    TOOLS_RUN=$((TOOLS_RUN + 1))
    local counts
    counts=$(count_sarif "$outfile")
    read -r c h m l <<< "$counts"
    log "Brakeman findings: C=$c H=$h M=$m L=$l"
  else
    log "Brakeman: no findings"
    TOOLS_RUN=$((TOOLS_RUN + 1))
  fi
}

run_gosec() {
  log_tool_header "Gosec (Go SAST)"

  if ! echo "$DETECTED_LANGS" | grep -qi "go"; then
    log "No Go detected, skipping Gosec"
    TOOLS_SKIPPED=$((TOOLS_SKIPPED + 1))
    return
  fi

  if ! ensure_tool gosec "curl -sSfL https://raw.githubusercontent.com/securego/gosec/master/install.sh | sh -s -- -b /usr/local/bin 2>/dev/null || (go install github.com/securego/gosec/v2/cmd/gosec@latest 2>/dev/null)"; then
    TOOLS_SKIPPED=$((TOOLS_SKIPPED + 1))
    return
  fi

  local outfile="$OUTPUT_DIR/gosec-results.sarif"
  log "Running Gosec..."

  gosec \
    -fmt sarif \
    -out "$outfile" \
    -severity medium \
    ./... 2>/dev/null || true

  if [ -s "$outfile" ]; then
    accumulate_findings "$outfile"
    SARIF_FILES+=("$outfile")
    TOOLS_RUN=$((TOOLS_RUN + 1))
    local counts
    counts=$(count_sarif "$outfile")
    read -r c h m l <<< "$counts"
    log "Gosec findings: C=$c H=$h M=$m L=$l"
  else
    log "Gosec: no findings"
    TOOLS_RUN=$((TOOLS_RUN + 1))
  fi
}

run_findsecbugs() {
  log_tool_header "FindSecBugs (Java SAST)"

  if ! echo "$DETECTED_LANGS" | grep -qi "java"; then
    log "No Java detected, skipping FindSecBugs"
    TOOLS_SKIPPED=$((TOOLS_SKIPPED + 1))
    return
  fi

  if ! command -v java &>/dev/null; then
    log "Java not installed, skipping FindSecBugs"
    TOOLS_SKIPPED=$((TOOLS_SKIPPED + 1))
    return
  fi

  local fsb_version="1.13.0"
  local fsb_url="https://github.com/find-sec-bugs/find-sec-bugs/releases/download/version-${fsb_version}/findsecbugs-cli-${fsb_version}.zip"
  local fsb_dir="/tmp/findsecbugs"

  if [ ! -d "$fsb_dir" ]; then
    log "Installing FindSecBugs..."
    mkdir -p "$fsb_dir"
    curl -sSfL "$fsb_url" -o /tmp/fsb.zip 2>/dev/null && \
      unzip -qo /tmp/fsb.zip -d "$fsb_dir" 2>/dev/null || {
        log "WARNING: Failed to install FindSecBugs"
        TOOLS_SKIPPED=$((TOOLS_SKIPPED + 1))
        return
      }
  fi

  local outfile="$OUTPUT_DIR/findsecbugs-results.sarif"
  log "Running FindSecBugs..."

  # Find Java source files
  local java_files=""
  while IFS= read -r f; do
    java_files="$java_files $f"
  done < <(find "$SCAN_DIR" -maxdepth 5 \( -name "*.java" -o -name "*.class" \) 2>/dev/null | head -500)

  if [ -z "$java_files" ]; then
    log "FindSecBugs: no Java files found"
    TOOLS_SKIPPED=$((TOOLS_SKIPPED + 1))
    return
  fi

  "$fsb_dir/findsecbugs-cli-1.13.0/bin/findsecbugs" \
    -sarif "$outfile" \
    -high $java_files 2>/dev/null || true

  if [ -s "$outfile" ]; then
    accumulate_findings "$outfile"
    SARIF_FILES+=("$outfile")
    TOOLS_RUN=$((TOOLS_RUN + 1))
    local counts
    counts=$(count_sarif "$outfile")
    read -r c h m l <<< "$counts"
    log "FindSecBugs findings: C=$c H=$h M=$m L=$l"
  else
    log "FindSecBugs: no findings"
    TOOLS_RUN=$((TOOLS_RUN + 1))
  fi
}

run_pmd() {
  log_tool_header "PMD (Java/Kotlin/Scala SAST)"

  if ! echo "$DETECTED_LANGS" | grep -qiE "java|kotlin|scala"; then
    log "No Java/Kotlin/Scala detected, skipping PMD"
    TOOLS_SKIPPED=$((TOOLS_SKIPPED + 1))
    return
  fi

  if ! ensure_tool pmd "curl -sSfL https://github.com/pmd/pmd/releases/download/pmd_releases%2F7.0.0/pmd-dist-7.0.0-bin.zip -o /tmp/pmd.zip && mkdir -p /opt/pmd && unzip -qo /tmp/pmd.zip -d /opt/pmd 2>/dev/null && ln -sf /opt/pmd/pmd-bin-7.0.0/bin/pmd /usr/local/bin/pmd"; then
    TOOLS_SKIPPED=$((TOOLS_SKIPPED + 1))
    return
  fi

  local outfile="$OUTPUT_DIR/pmd-results.xml"
  log "Running PMD..."

  local languages=""
  echo "$DETECTED_LANGS" | grep -qi "java" && languages="$languages java"
  echo "$DETECTED_LANGS" | grep -qi "kotlin" && languages="$languages kotlin"
  echo "$DETECTED_LANGS" | grep -qi "scala" && languages="$languages scala"

  if [ -z "$languages" ]; then
    languages=" java"
  fi

  for lang in $languages; do
    local lang_outfile="$OUTPUT_DIR/pmd-${lang}-results.xml"
    pmd check \
      -d "$SCAN_DIR" \
      -R "category/${lang}/errorprone.xml,category/${lang}/security.xml" \
      -f xml \
      -r "$lang_outfile" \
      --no-cache 2>/dev/null || true

    if [ -s "$lang_outfile" ]; then
      # Convert PMD XML to SARIF-like counts
      local issues
      issues=$(grep -c '<violation' "$lang_outfile" 2>/dev/null || echo "0")
      if [ "$issues" -gt 0 ]; then
        TOTAL_MEDIUM=$((TOTAL_MEDIUM + issues))
        TOTAL_FINDINGS=$((TOTAL_FINDINGS + issues))
        log "PMD ($lang): $issues findings"
      fi
    fi
  done

  TOOLS_RUN=$((TOOLS_RUN + 1))
}

# ============================================================================
# SCA Scanners
# ============================================================================
run_osv_scanner() {
  log_tool_header "OSV-Scanner (SCA)"

  if ! ensure_tool osv-scanner "curl -sSfL https://raw.githubusercontent.com/google/osv-scanner/main/install.sh | sh -s -- -b /usr/local/bin 2>/dev/null || (OSV_VERSION=\$(curl -s https://api.github.com/repos/google/osv-scanner/releases/latest | grep tag_name | cut -d'\"' -f4) && curl -sSfL \"https://github.com/google/osv-scanner/releases/download/\${OSV_VERSION}/osv-scanner_\${OSV_VERSION#v}_linux_amd64\" -o /usr/local/bin/osv-scanner && chmod +x /usr/local/bin/osv-scanner)"; then
    TOOLS_SKIPPED=$((TOOLS_SKIPPED + 1))
    return
  fi

  local outfile="$OUTPUT_DIR/osv-results.json"
  log "Running OSV-Scanner..."

  osv-scanner \
    --format json \
    --output "$outfile" \
    "$SCAN_DIR" 2>/dev/null || true

  # Also produce table output for human readability
  osv-scanner --format table "$SCAN_DIR" 2>/dev/null || true

  if [ -s "$outfile" ]; then
    local total
    total=$(python3 -c "
import json,sys
try:
  d=json.load(open('$outfile'))
  print(sum(len(v.get('vulns',[])) for v in d.get('results',[])))
except: print(0)
" 2>/dev/null || echo "0")
    TOTAL_HIGH=$((TOTAL_HIGH + total))
    TOTAL_FINDINGS=$((TOTAL_FINDINGS + total))
    TOOLS_RUN=$((TOOLS_RUN + 1))
    log "OSV-Scanner vulnerabilities: $total"
  else
    log "OSV-Scanner: no vulnerabilities found"
    TOOLS_RUN=$((TOOLS_RUN + 1))
  fi
}

run_trivy_sca() {
  log_tool_header "Trivy Filesystem Scan (SCA + Secrets + Misconfig)"

  if ! ensure_tool trivy "curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh | sh -s -- -b /usr/local/bin 2>/dev/null || (wget -qO- https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh | sh -s -- -b /usr/local/bin)"; then
    TOOLS_SKIPPED=$((TOOLS_SKIPPED + 1))
    return
  fi

  local outfile="$OUTPUT_DIR/trivy-fs-results.sarif"
  log "Running Trivy filesystem scan..."

  trivy fs \
    --format sarif \
    --output "$outfile" \
    --severity CRITICAL,HIGH,MEDIUM \
    --scanners vuln,secret,misconfig \
    --ignore-unfixed \
    "$SCAN_DIR" 2>/dev/null || true

  if [ -s "$outfile" ]; then
    accumulate_findings "$outfile"
    SARIF_FILES+=("$outfile")
    TOOLS_RUN=$((TOOLS_RUN + 1))
    local counts
    counts=$(count_sarif "$outfile")
    read -r c h m l <<< "$counts"
    log "Trivy FS findings: C=$c H=$h M=$m L=$l"
  else
    log "Trivy FS: no findings"
    TOOLS_RUN=$((TOOLS_RUN + 1))
  fi
}

run_grype() {
  log_tool_header "Grype (SCA)"

  if ! ensure_tool grype "curl -sSfL https://raw.githubusercontent.com/anchore/grype/main/install.sh | sh -s -- -b /usr/local/bin 2>/dev/null || (curl -sSfL https://github.com/anchore/grype/releases/latest/download/grype_linux_amd64.tar.gz | tar xz -C /usr/local/bin grype)"; then
    TOOLS_SKIPPED=$((TOOLS_SKIPPED + 1))
    return
  fi

  local outfile="$OUTPUT_DIR/grype-results.sarif"
  log "Running Grype..."

  grype "$SCAN_DIR:/" \
    --output sarif \
    --file "$outfile" \
    --fail-on critical 2>/dev/null || true

  if [ -s "$outfile" ]; then
    accumulate_findings "$outfile"
    SARIF_FILES+=("$outfile")
    TOOLS_RUN=$((TOOLS_RUN + 1))
    local counts
    counts=$(count_sarif "$outfile")
    read -r c h m l <<< "$counts"
    log "Grype findings: C=$c H=$h M=$m L=$l"
  else
    log "Grype: no findings"
    TOOLS_RUN=$((TOOLS_RUN + 1))
  fi
}

# ============================================================================
# Secret Detection
# ============================================================================
run_gitleaks() {
  log_tool_header "Gitleaks (Secret Detection)"

  if ! ensure_tool gitleaks "GITLEAKS_VERSION=\$(curl -s https://api.github.com/repos/gitleaks/gitleaks/releases/latest | grep tag_name | cut -d'\"' -f4) && curl -sSfL \"https://github.com/gitleaks/gitleaks/releases/download/\${GITLEAKS_VERSION}/gitleaks_\${GITLEAKS_VERSION#v}_linux_x64.tar.gz\" | tar xz -C /usr/local/bin gitleaks"; then
    TOOLS_SKIPPED=$((TOOLS_SKIPPED + 1))
    return
  fi

  local outfile="$OUTPUT_DIR/gitleaks-results.sarif"
  log "Running Gitleaks..."

  gitleaks detect \
    --source "$SCAN_DIR" \
    --report-format sarif \
    --report-path "$outfile" \
    --redact \
    --verbose 2>&1 || true

  if [ -s "$outfile" ]; then
    accumulate_findings "$outfile"
    SARIF_FILES+=("$outfile")
    TOOLS_RUN=$((TOOLS_RUN + 1))
    local counts
    counts=$(count_sarif "$outfile")
    read -r c h m l <<< "$counts"
    log "Gitleaks findings: C=$c H=$h M=$m L=$l"
  else
    log "Gitleaks: no secrets found"
    TOOLS_RUN=$((TOOLS_RUN + 1))
  fi
}

run_trufflehog() {
  log_tool_header "TruffleHog (Deep Secret Scanning)"

  if ! ensure_tool trufflehog "curl -sSfL https://raw.githubusercontent.com/trufflesecurity/trufflehog/main/scripts/install.sh | sh -s -- -b /usr/local/bin 2>/dev/null || (go install github.com/trufflesecurity/trufflehog/v3@latest 2>/dev/null)"; then
    TOOLS_SKIPPED=$((TOOLS_SKIPPED + 1))
    return
  fi

  local outfile="$OUTPUT_DIR/trufflehog-results.json"
  log "Running TruffleHog..."

  if [ -d "$SCAN_DIR/.git" ]; then
    trufflehog git "file://$SCAN_DIR" --only-verified --json 2>/dev/null > "$outfile" || true
  else
    trufflehog filesystem "$SCAN_DIR" --only-verified --json 2>/dev/null > "$outfile" || true
  fi

  local count=0
  if [ -s "$outfile" ]; then
    count=$(python3 -c "
import sys, json
c = 0
for line in open('$outfile'):
    try:
        d = json.loads(line)
        if d.get('DetectorName'):
            c += 1
    except: pass
print(c)
" 2>/dev/null || echo "0")
  fi

  TOTAL_HIGH=$((TOTAL_HIGH + count))
  TOTAL_FINDINGS=$((TOTAL_FINDINGS + count))
  TOOLS_RUN=$((TOOLS_RUN + 1))
  log "TruffleHog verified secrets: $count"
}

run_detect_secrets() {
  log_tool_header "detect-secrets (Secret Detection)"

  if ! ensure_tool detect-secrets "pip3 install detect-secrets 2>/dev/null || pip install detect-secrets 2>/dev/null"; then
    TOOLS_SKIPPED=$((TOOLS_SKIPPED + 1))
    return
  fi

  local outfile="$OUTPUT_DIR/detect-secrets-results.json"
  log "Running detect-secrets..."

  detect-secrets scan \
    --all-files \
    --force-use-all-plugins \
    "$SCAN_DIR" \
    --output "$outfile" 2>/dev/null || true

  if [ -s "$outfile" ]; then
    local count
    count=$(python3 -c "
import json
try:
  d = json.load(open('$outfile'))
  results = d.get('results', {})
  print(sum(len(v) for v in results.values()))
except: print(0)
" 2>/dev/null || echo "0")
    TOTAL_MEDIUM=$((TOTAL_MEDIUM + count))
    TOTAL_FINDINGS=$((TOTAL_FINDINGS + count))
    TOOLS_RUN=$((TOOLS_RUN + 1))
    log "detect-secrets findings: $count"
  else
    log "detect-secrets: no findings"
    TOOLS_RUN=$((TOOLS_RUN + 1))
  fi
}

# ============================================================================
# Container Scanning
# ============================================================================
run_hadolint() {
  log_tool_header "Hadolint (Dockerfile Linting)"

  local dockerfiles
  dockerfiles=$(find "$SCAN_DIR" -maxdepth 4 -name "Dockerfile*" -o -name "*.dockerfile" 2>/dev/null)

  if [ -z "$dockerfiles" ]; then
    log "No Dockerfiles found, skipping Hadolint"
    TOOLS_SKIPPED=$((TOOLS_SKIPPED + 1))
    return
  fi

  if ! ensure_tool hadolint "curl -sSfL https://github.com/hadolint/hadolint/releases/latest/download/hadolint-Linux-x86_64 -o /usr/local/bin/hadolint && chmod +x /usr/local/bin/hadolint 2>/dev/null || (docker pull hadolint/hadolint && alias hadolint='docker run --rm -i hadolint/hadolint')"; then
    TOOLS_SKIPPED=$((TOOLS_SKIPPED + 1))
    return
  fi

  local outfile="$OUTPUT_DIR/hadolint-results.sarif"
  log "Running Hadolint..."

  local all_findings=0
  while IFS= read -r dockerfile; do
    [ -f "$dockerfile" ] || continue
    local df_outfile="$OUTPUT_DIR/hadolint-$(basename "$(dirname "$dockerfile")")-results.sarif"
    hadolint --format sarif "$dockerfile" > "$df_outfile" 2>/dev/null || true

    if [ -s "$df_outfile" ]; then
      accumulate_findings "$df_outfile"
      SARIF_FILES+=("$df_outfile")
      local counts
      counts=$(count_sarif "$df_outfile")
      read -r c h m l <<< "$counts"
      all_findings=$((all_findings + c + h + m + l))
    fi
  done <<< "$dockerfiles"

  TOOLS_RUN=$((TOOLS_RUN + 1))
  log "Hadolint findings: $all_findings"
}

run_dockle() {
  log_tool_header "Dockle (Container Image Linting)"

  if ! command -v docker &>/dev/null; then
    log "Docker not available, skipping Dockle"
    TOOLS_SKIPPED=$((TOOLS_SKIPPED + 1))
    return
  fi

  if ! ensure_tool dockle "DOCKLE_VERSION=\$(curl -s https://api.github.com/repos/goodwithtech/dockle/releases/latest | grep tag_name | cut -d'\"' -f4) && curl -sSfL \"https://github.com/goodwithtech/dockle/releases/download/\${DOCKLE_VERSION}/dockle_\${DOCKLE_VERSION#v}_Linux-64bit.tar.gz\" | tar xz -C /usr/local/bin dockle"; then
    TOOLS_SKIPPED=$((TOOLS_SKIPPED + 1))
    return
  fi

  # Check for Docker images to scan
  local images
  images=$(docker images --format '{{.Repository}}:{{.Tag}}' 2>/dev/null | grep -v '<none>' | head -5)

  if [ -z "$images" ]; then
    log "No Docker images found, skipping Dockle"
    TOOLS_SKIPPED=$((TOOLS_SKIPPED + 1))
    return
  fi

  log "Running Dockle..."

  while IFS= read -r image; do
    [ -z "$image" ] && continue
    log "Scanning image: $image"
    dockle --format json --output "$OUTPUT_DIR/dockle-$(echo "$image" | tr '/:' '-').json" "$image" 2>/dev/null || true
  done <<< "$images"

  TOOLS_RUN=$((TOOLS_RUN + 1))
}

run_trivy_image() {
  log_tool_header "Trivy Image Scan (Container)"

  if ! command -v docker &>/dev/null; then
    log "Docker not available, skipping Trivy image scan"
    TOOLS_SKIPPED=$((TOOLS_SKIPPED + 1))
    return
  fi

  if ! command -v trivy &>/dev/null; then
    log "Trivy not installed, skipping image scan"
    TOOLS_SKIPPED=$((TOOLS_SKIPPED + 1))
    return
  fi

  local images
  images=$(docker images --format '{{.Repository}}:{{.Tag}}' 2>/dev/null | grep -v '<none>' | head -5)

  if [ -z "$images" ]; then
    log "No Docker images found, skipping Trivy image scan"
    TOOLS_SKIPPED=$((TOOLS_SKIPPED + 1))
    return
  fi

  log "Running Trivy image scan..."

  while IFS= read -r image; do
    [ -z "$image" ] && continue
    local outfile="$OUTPUT_DIR/trivy-image-$(echo "$image" | tr '/:' '-').sarif"
    log "Scanning image: $image"
    trivy image \
      --format sarif \
      --output "$outfile" \
      --severity CRITICAL,HIGH,MEDIUM \
      "$image" 2>/dev/null || true

    if [ -s "$outfile" ]; then
      accumulate_findings "$outfile"
      SARIF_FILES+=("$outfile")
    fi
  done <<< "$images"

  TOOLS_RUN=$((TOOLS_RUN + 1))
}

# ============================================================================
# IaC Scanners
# ============================================================================
run_checkov() {
  log_tool_header "Checkov (IaC Security)"

  if ! ensure_tool checkov "pip3 install checkov 2>/dev/null || pip install checkov 2>/dev/null"; then
    TOOLS_SKIPPED=$((TOOLS_SKIPPED + 1))
    return
  fi

  local outfile="$OUTPUT_DIR/checkov-results.sarif"
  log "Running Checkov..."

  checkov \
    -d "$SCAN_DIR" \
    --output sarif \
    --output-file "$outfile" \
    --compact \
    --quiet 2>/dev/null || true

  if [ -s "$outfile" ]; then
    accumulate_findings "$outfile"
    SARIF_FILES+=("$outfile")
    TOOLS_RUN=$((TOOLS_RUN + 1))
    local counts
    counts=$(count_sarif "$outfile")
    read -r c h m l <<< "$counts"
    log "Checkov findings: C=$c H=$h M=$m L=$l"
  else
    log "Checkov: no findings"
    TOOLS_RUN=$((TOOLS_RUN + 1))
  fi
}

run_tflint() {
  log_tool_header "TFLint (Terraform Linting)"

  local tf_files
  tf_files=$(find "$SCAN_DIR" -maxdepth 5 -name "*.tf" 2>/dev/null | head -1)

  if [ -z "$tf_files" ]; then
    log "No Terraform files found, skipping TFLint"
    TOOLS_SKIPPED=$((TOOLS_SKIPPED + 1))
    return
  fi

  if ! ensure_tool tflint "curl -sSfL https://github.com/terraform-linters/tflint/releases/latest/download/tflint_linux_amd64.zip -o /tmp/tflint.zip && unzip -qo /tmp/tflint.zip -d /usr/local/bin 2>/dev/null"; then
    TOOLS_SKIPPED=$((TOOLS_SKIPPED + 1))
    return
  fi

  local outfile="$OUTPUT_DIR/tflint-results.json"
  log "Running TFLint..."

  tflint \
    --chdir "$SCAN_DIR" \
    --format json \
    --output "$outfile" \
    --recursive 2>/dev/null || true

  if [ -s "$outfile" ]; then
    local count
    count=$(python3 -c "
import json
try:
  d = json.load(open('$outfile'))
  issues = d.get('issues', [])
  print(len(issues))
except: print(0)
" 2>/dev/null || echo "0")
    TOTAL_MEDIUM=$((TOTAL_MEDIUM + count))
    TOTAL_FINDINGS=$((TOTAL_FINDINGS + count))
    TOOLS_RUN=$((TOOLS_RUN + 1))
    log "TFLint findings: $count"
  else
    log "TFLint: no findings"
    TOOLS_RUN=$((TOOLS_RUN + 1))
  fi
}

run_kics() {
  log_tool_header "KICS (IaC Security)"

  if ! ensure_tool kics "curl -sSfL https://github.com/Checkmarx/kics/releases/latest/download/kics_$(curl -s https://api.github.com/repos/Checkmarx/kics/releases/latest | grep tag_name | cut -d'\"' -f4 | sed 's/v//')_linux_x64.tar.gz | tar xz -C /usr/local/bin kics 2>/dev/null"; then
    TOOLS_SKIPPED=$((TOOLS_SKIPPED + 1))
    return
  fi

  local outfile="$OUTPUT_DIR/kics-results.sarif"
  log "Running KICS..."

  kics scan \
    --path "$SCAN_DIR" \
    --output-path "$OUTPUT_DIR" \
    --output-name "kics-results" \
    --report-formats sarif \
    --exclude-queries "2c107168-870b-4971-b26a-694f55a78c80" \
    --severity-info \
    --fail-on "crITICAL,hIgH" 2>/dev/null || true

  if [ -s "$outfile" ]; then
    accumulate_findings "$outfile"
    SARIF_FILES+=("$outfile")
    TOOLS_RUN=$((TOOLS_RUN + 1))
    local counts
    counts=$(count_sarif "$outfile")
    read -r c h m l <<< "$counts"
    log "KICS findings: C=$c H=$h M=$m L=$l"
  else
    log "KICS: no findings"
    TOOLS_RUN=$((TOOLS_RUN + 1))
  fi
}

run_trivy_config() {
  log_tool_header "Trivy Config Scan (IaC)"

  if ! command -v trivy &>/dev/null; then
    log "Trivy not installed, skipping config scan"
    TOOLS_SKIPPED=$((TOOLS_SKIPPED + 1))
    return
  fi

  local outfile="$OUTPUT_DIR/trivy-config-results.sarif"
  log "Running Trivy config scan..."

  trivy config \
    --format sarif \
    --output "$outfile" \
    --severity CRITICAL,HIGH,MEDIUM \
    --scanners misconfig \
    "$SCAN_DIR" 2>/dev/null || true

  if [ -s "$outfile" ]; then
    accumulate_findings "$outfile"
    SARIF_FILES+=("$outfile")
    TOOLS_RUN=$((TOOLS_RUN + 1))
    local counts
    counts=$(count_sarif "$outfile")
    read -r c h m l <<< "$counts"
    log "Trivy Config findings: C=$c H=$h M=$m L=$l"
  else
    log "Trivy Config: no findings"
    TOOLS_RUN=$((TOOLS_RUN + 1))
  fi
}

# ============================================================================
# Merge SARIF files
# ============================================================================
merge_sarif_files() {
  if [ "${#SARIF_FILES[@]}" -le 1 ]; then
    return
  fi

  log "Merging ${#SARIF_FILES[@]} SARIF files..."

  python3 -c "
import json, sys

files = sys.argv[1:]
merged = {'version': '2.1.0', '$schema': 'https://json.schemastore.org/sarif-2.1.0.json', 'runs': []}

for f in files:
    try:
        with open(f) as fh:
            data = json.load(fh)
            if 'runs' in data:
                merged['runs'].extend(data['runs'])
    except: pass

with open('$OUTPUT_DIR/merged-results.sarif', 'w') as out:
    json.dump(merged, out, indent=2)
print(f'Merged SARIF written to $OUTPUT_DIR/merged-results.sarif')
" "${SARIF_FILES[@]}" 2>/dev/null || log "WARNING: SARIF merge failed"
}

# ============================================================================
# Summary & Exit
# ============================================================================
print_summary() {
  log_section "Security Scan Summary"

  echo "  Languages detected: $DETECTED_LANGS"
  echo "  Categories scanned: $SCAN_CATEGORIES"
  echo "  FAIL_ON threshold:  $FAIL_ON"
  echo ""
  echo "  Tools run:    $TOOLS_RUN"
  echo "  Tools skipped: $TOOLS_SKIPPED"
  echo ""
  echo "  ----------------------------------------"
  echo "  Findings by severity:"
  echo "  ----------------------------------------"
  echo "  Critical: $TOTAL_CRITICAL"
  echo "  High:     $TOTAL_HIGH"
  echo "  Medium:   $TOTAL_MEDIUM"
  echo "  Low:      $TOTAL_LOW"
  echo "  ----------------------------------------"
  echo "  Total:     $TOTAL_FINDINGS"
  echo ""

  # Calculate health score
  SCORE=100
  SCORE=$((SCORE - TOTAL_CRITICAL * 10))
  SCORE=$((SCORE - TOTAL_HIGH * 3))
  SCORE=$((SCORE - TOTAL_MEDIUM * 1))
  [ "$SCORE" -lt 0 ] && SCORE=0
  echo "  Health Score: $SCORE/100"
  echo ""

  # List SARIF files
  if [ "${#SARIF_FILES[@]}" -gt 0 ]; then
    echo "  SARIF output files:"
    for f in "${SARIF_FILES[@]}"; do
      [ -f "$f" ] && echo "    - $f"
    done
    if [ -f "$OUTPUT_DIR/merged-results.sarif" ]; then
      echo "    - $OUTPUT_DIR/merged-results.sarif (merged)"
    fi
  fi
  echo ""

  # GitHub Actions outputs
  if [ -n "${GITHUB_OUTPUT:-}" ]; then
    local sarif_list=""
    for f in "${SARIF_FILES[@]}"; do
      [ -f "$f" ] || continue
      [ -z "$sarif_list" ] && sarif_list="$f" || sarif_list="$sarif_list,$f"
    done
    [ -f "$OUTPUT_DIR/merged-results.sarif" ] && {
      [ -z "$sarif_list" ] && sarif_list="$OUTPUT_DIR/merged-results.sarif" || sarif_list="$sarif_list,$OUTPUT_DIR/merged-results.sarif"
    }

    {
      echo "report<<EOF"
      echo "## iDevOps Security Report"
      echo ""
      echo "- Languages: $DETECTED_LANGS"
      echo "- Critical: $TOTAL_CRITICAL"
      echo "- High: $TOTAL_HIGH"
      echo "- Medium: $TOTAL_MEDIUM"
      echo "- Low: $TOTAL_LOW"
      echo "- Score: $SCORE/100"
      echo "EOF"
      echo "score=$SCORE"
      echo "critical=$TOTAL_CRITICAL"
      echo "high=$TOTAL_HIGH"
      echo "medium=$TOTAL_MEDIUM"
      echo "low=$TOTAL_LOW"
      echo "total=$TOTAL_FINDINGS"
      echo "files=$sarif_list"
    } >> "$GITHUB_OUTPUT"
  fi
}

# ============================================================================
# Main
# ============================================================================
main() {
  log_section "Universal Security Scanner"
  log "FAIL_ON:       $FAIL_ON"
  log "LANGUAGES:     $LANGUAGES"
  log "SCAN_CATEGORIES: $SCAN_CATEGORIES"
  log "SCAN_DIR:      $SCAN_DIR"
  log "OUTPUT_DIR:    $OUTPUT_DIR"

  # Create output directory
  mkdir -p "$OUTPUT_DIR"

  # Detect languages
  DETECTED_LANGS=$(detect_languages)
  if [ -z "$DETECTED_LANGS" ]; then
    DETECTED_LANGS="unknown"
  fi
  log "Detected languages: $DETECTED_LANGS"

  # Parse categories
  local do_sast=false do_sca=false do_secrets=false do_container=false do_iac=false
  if echo "$SCAN_CATEGORIES" | grep -qi "sast"; then do_sast=true; fi
  if echo "$SCAN_CATEGORIES" | grep -qi "sca"; then do_sca=true; fi
  if echo "$SCAN_CATEGORIES" | grep -qi "secrets"; then do_secrets=true; fi
  if echo "$SCAN_CATEGORIES" | grep -qi "container"; then do_container=true; fi
  if echo "$SCAN_CATEGORIES" | grep -qi "iac"; then do_iac=true; fi

  # ---- SAST ----
  if $do_sast; then
    log_section "SAST Scanners"
    run_semgrep
    run_bandit
    run_brakeman
    run_gosec
    run_findsecbugs
    run_pmd
  fi

  # ---- SCA ----
  if $do_sca; then
    log_section "SCA Scanners"
    run_osv_scanner
    run_trivy_sca
    run_grype
  fi

  # ---- Secrets ----
  if $do_secrets; then
    log_section "Secret Detection"
    run_gitleaks
    run_trufflehog
    run_detect_secrets
  fi

  # ---- Container ----
  if $do_container; then
    log_section "Container Scanning"
    run_hadolint
    run_dockle
    run_trivy_image
  fi

  # ---- IaC ----
  if $do_iac; then
    log_section "IaC Scanning"
    run_checkov
    run_tflint
    run_kics
    run_trivy_config
  fi

  # Merge SARIF if requested
  if [ "$SARIF_MERGE" = "true" ]; then
    merge_sarif_files
  fi

  # Print summary
  print_summary

  # Determine exit code based on severity threshold
  log_section "Final Verdict"

  local exit_code=0
  if [ "$FAIL_ON_NUM" -eq 0 ]; then
    log "PASS: Threshold set to 'never' - always passing"
    exit_code=0
  elif [ "$FAIL_ON_NUM" -le 4 ] && [ "$TOTAL_CRITICAL" -gt 0 ]; then
    log "FAIL: $TOTAL_CRITICAL critical findings (threshold: $FAIL_ON)"
    exit_code=1
  elif [ "$FAIL_ON_NUM" -le 3 ] && [ "$TOTAL_HIGH" -gt 0 ]; then
    log "FAIL: $TOTAL_HIGH high findings (threshold: $FAIL_ON)"
    exit_code=1
  elif [ "$FAIL_ON_NUM" -le 2 ] && [ "$TOTAL_MEDIUM" -gt 0 ]; then
    log "FAIL: $TOTAL_MEDIUM medium findings (threshold: $FAIL_ON)"
    exit_code=1
  elif [ "$FAIL_ON_NUM" -le 1 ] && [ "$TOTAL_LOW" -gt 0 ]; then
    log "FAIL: $TOTAL_LOW low findings (threshold: $FAIL_ON)"
    exit_code=1
  else
    log "PASS: No findings above threshold '$FAIL_ON'"
    exit_code=0
  fi

  echo ""
  echo "=========================================================="
  if [ "$exit_code" -eq 0 ]; then
    echo "  [iDevOps] SECURITY SCAN PASSED"
  else
    echo "  [iDevOps] SECURITY SCAN FAILED"
  fi
  echo "=========================================================="
  echo ""

  return "$exit_code"
}

main "$@"
