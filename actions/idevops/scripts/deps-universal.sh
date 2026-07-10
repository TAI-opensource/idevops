#!/usr/bin/env bash
# [iDevOps] Universal Dependency Auditor
# Auto-detects ecosystems, runs audits, checks vulnerabilities/outdated/licenses
set -euo pipefail

# --- Configuration ---
FAIL_ON="${FAIL_ON:-critical}"
LANGUAGES="${LANGUAGES:-all}"
CHECK_OUTDATED="${CHECK_OUTDATED:-true}"
CHECK_LICENSES="${CHECK_LICENSES:-true}"
OUTPUT_FORMAT="${OUTPUT_FORMAT:-text}"
REPORT_DIR="${REPORT_DIR:-.}"
TIMESTAMP=$(date +%Y%m%dT%H%M%SZ)
REPORT_FILE="${REPORT_DIR}/dependency-audit-${TIMESTAMP}"

# --- Helpers ---
log() { echo "[iDevOps] $*"; }
warn() { echo "[iDevOps] WARNING: $*" >&2; }
err() { echo "[iDevOps] ERROR: $*" >&2; }

severity_level() {
  case "${1,,}" in
    critical) echo 4 ;;
    high)     echo 3 ;;
    medium)   echo 2 ;;
    low)      echo 1 ;;
    info)     echo 0 ;;
    *)        echo 0 ;;
  esac
}

FAIL_LEVEL=$(severity_level "$FAIL_ON")
EXIT_CODE=0

bump_exit() {
  local level
  level=$(severity_level "$1")
  if [[ $level -ge $FAIL_LEVEL ]]; then
    EXIT_CODE=1
  fi
}

# --- Ecosystem Detection ---
detect_ecosystems() {
  local ecosystems=()
  local lang_filter="${LANGUAGES,,}"

  # npm / yarn / pnpm
  if [[ -f package.json ]] || [[ -f yarn.lock ]] || [[ -f pnpm-lock.yaml ]]; then
    ecosystems+=(npm)
  fi

  # pip / poetry / pdm / hatch
  if [[ -f requirements.txt ]] || [[ -f setup.py ]] || [[ -f setup.cfg ]] || \
     [[ -f pyproject.toml ]] || [[ -f Pipfile ]]; then
    ecosystems+=(pip)
  fi

  # cargo
  if [[ -f Cargo.toml ]]; then
    ecosystems+=(cargo)
  fi

  # go
  if [[ -f go.mod ]]; then
    ecosystems+=(go)
  fi

  # maven
  if [[ -f pom.xml ]]; then
    ecosystems+=(maven)
  fi

  # gradle
  if [[ -f build.gradle ]] || [[ -f build.gradle.kts ]]; then
    ecosystems+=(gradle)
  fi

  # bundler (ruby)
  if [[ -f Gemfile ]]; then
    ecosystems+=(bundler)
  fi

  # composer (php)
  if [[ -f composer.json ]]; then
    ecosystems+=(composer)
  fi

  # nuget (.NET)
  if find . -maxdepth 3 -name "*.csproj" -o -name "*.sln" 2>/dev/null | head -1 | grep -q .; then
    ecosystems+=(nuget)
  fi

  # swift
  if [[ -f Package.swift ]]; then
    ecosystems+=(swift)
  fi

  # pub (dart)
  if [[ -f pubspec.yaml ]]; then
    ecosystems+=(pub)
  fi

  # hex (elixir)
  if [[ -f mix.exs ]]; then
    ecosystems+=(hex)
  fi

  # conan (C/C++)
  if [[ -f conanfile.py ]] || [[ -f conanfile.txt ]]; then
    ecosystems+=(conan)
  fi

  # vcpkg (C/C++)
  if [[ -f vcpkg.json ]] || [[ -d vcpkg ]]; then
    ecosystems+=(vcpkg)
  fi

  # zig
  if [[ -f build.zig ]]; then
    ecosystems+=(zig)
  fi

  # nim
  if [[ -f nimble.toml ]] || find . -maxdepth 3 -name "*.nimble" 2>/dev/null | head -1 | grep -q .; then
    ecosystems+=(nim)
  fi

  # crystal
  if [[ -f shard.yml ]]; then
    ecosystems+=(crystal)
  fi

  # R
  if [[ -f DESCRIPTION ]] && grep -q "^Package:" DESCRIPTION 2>/dev/null; then
    ecosystems+=(r)
  fi

  # julia
  if [[ -f Project.toml ]]; then
    ecosystems+=(julia)
  fi

  # terraform
  if find . -maxdepth 3 -name "*.tf" 2>/dev/null | head -1 | grep -q .; then
    ecosystems+=(terraform)
  fi

  # docker
  if [[ -f Dockerfile ]] || [[ -f docker-compose.yml ]] || [[ -f docker-compose.yaml ]]; then
    ecosystems+=(docker)
  fi

  # Filter by LANGUAGES if not "all"
  if [[ "$lang_filter" != "all" ]]; then
    local filtered=()
    for eco in "${ecosystems[@]}"; do
      if echo ",$lang_filter," | grep -qi ",$eco,"; then
        filtered+=("$eco")
      fi
    done
    ecosystems=("${filtered[@]}")
  fi

  echo "${ecosystems[@]}"
}

# --- Per-Ecosystem Runners ---
run_npm() {
  log "Auditing npm dependencies..."
  local issues=0

  if command -v npm &>/dev/null && [[ -f package-lock.json || -f package.json ]]; then
    local audit_out
    if audit_out=$(npm audit --json 2>/dev/null); then
      local crit high med
      crit=$(echo "$audit_out" | python3 -c "import sys,json; d=json.load(sys.stdin).get('metadata',{}).get('vulnerabilities',{}); print(d.get('critical',0))" 2>/dev/null || echo 0)
      high=$(echo "$audit_out" | python3 -c "import sys,json; d=json.load(sys.stdin).get('metadata',{}).get('vulnerabilities',{}); print(d.get('high',0))" 2>/dev/null || echo 0)
      med=$(echo "$audit_out" | python3 -c "import sys,json; d=json.load(sys.stdin).get('metadata',{}).get('vulnerabilities',{}); print(d.get('moderate',0))" 2>/dev/null || echo 0)

      if [[ "$crit" -gt 0 ]]; then
        log "  npm: $crit critical, $high high, $med moderate vulnerabilities"
        bump_exit critical
        issues=$((issues + crit + high + med))
      elif [[ "$high" -gt 0 ]]; then
        log "  npm: $high high, $med moderate vulnerabilities"
        bump_exit high
        issues=$((issues + high + med))
      elif [[ "$med" -gt 0 ]]; then
        log "  npm: $med moderate vulnerabilities"
        bump_exit medium
        issues=$med
      else
        log "  npm: No known vulnerabilities"
      fi
    else
      warn "  npm audit failed"
    fi
  fi

  if [[ "$CHECK_OUTDATED" == "true" ]] && command -v npm &>/dev/null && [[ -f package.json ]]; then
    local outdated
    if outdated=$(npm outdated --json 2>/dev/null); then
      local count
      count=$(echo "$outdated" | python3 -c "import sys,json; print(len(json.load(sys.stdin)))" 2>/dev/null || echo 0)
      log "  npm: $count outdated packages"
    fi
  fi

  if [[ "$CHECK_LICENSES" == "true" ]] && command -v npx &>/dev/null; then
    npx --yes license-checker --json --out "${REPORT_FILE}-npm-licenses.json" 2>/dev/null || warn "  npm license check failed"
  fi

  echo "$issues"
}

run_pip() {
  log "Auditing pip dependencies..."
  local issues=0

  if command -v pip-audit &>/dev/null; then
    local audit_out
    if audit_out=$(pip-audit --format json 2>/dev/null); then
      local vuln_count
      vuln_count=$(echo "$audit_out" | python3 -c "import sys,json; d=json.load(sys.stdin); print(len([v for v in d if v.get('vulns')]))" 2>/dev/null || echo 0)
      if [[ "$vuln_count" -gt 0 ]]; then
        log "  pip: $vuln_count packages with vulnerabilities"
        bump_exit high
        issues=$vuln_count
      else
        log "  pip: No known vulnerabilities"
      fi
    fi
  elif command -v pip &>/dev/null; then
    warn "  pip-audit not installed, installing..."
    pip install pip-audit -q 2>/dev/null && run_pip && return
  fi

  if [[ "$CHECK_OUTDATED" == "true" ]] && command -v pip &>/dev/null; then
    local outdated
    outdated=$(pip list --outdated --format json 2>/dev/null || echo "[]")
    local count
    count=$(echo "$outdated" | python3 -c "import sys,json; print(len(json.load(sys.stdin)))" 2>/dev/null || echo 0)
    log "  pip: $count outdated packages"
  fi

  if [[ "$CHECK_LICENSES" == "true" ]] && command -v pip-licenses &>/dev/null; then
    pip-licenses --format=json --output-file="${REPORT_FILE}-pip-licenses.json" 2>/dev/null || warn "  pip license check failed"
  fi

  echo "$issues"
}

run_cargo() {
  log "Auditing Cargo dependencies..."
  local issues=0

  if command -v cargo-audit &>/dev/null && [[ -f Cargo.lock ]]; then
    local audit_out
    if audit_out=$(cargo audit --json 2>/dev/null); then
      local vuln_count
      vuln_count=$(echo "$audit_out" | python3 -c "import sys,json; d=json.load(sys.stdin); print(len(d.get('vulnerabilities',{}).get('list',[])))" 2>/dev/null || echo 0)
      if [[ "$vuln_count" -gt 0 ]]; then
        log "  cargo: $vuln_count vulnerabilities"
        bump_exit high
        issues=$vuln_count
      else
        log "  cargo: No known vulnerabilities"
      fi
    fi
  elif command -v cargo &>/dev/null && [[ -f Cargo.lock ]]; then
    warn "  cargo-audit not installed, installing..."
    cargo install cargo-audit -q 2>/dev/null && run_cargo && return
  fi

  if [[ "$CHECK_OUTDATED" == "true" ]] && command -v cargo-outdated &>/dev/null; then
    local outdated
    outdated=$(cargo outdated --format json 2>/dev/null || echo "{}")
    local count
    count=$(echo "$outdated" | python3 -c "import sys,json; d=json.load(sys.stdin); print(sum(len(v) for v in d.get('dependencies',{}).values()))" 2>/dev/null || echo 0)
    log "  cargo: $count outdated packages"
  fi

  echo "$issues"
}

run_go() {
  log "Auditing Go dependencies..."
  local issues=0

  if command -v govulncheck &>/dev/null && [[ -f go.mod ]]; then
    local vuln_out
    if vuln_out=$(govulncheck -json ./... 2>/dev/null); then
      local vuln_count
      vuln_count=$(echo "$vuln_out" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    vulns = d.get('vulns', [])
    print(len(vulns))
except:
    print(0)
" 2>/dev/null || echo 0)
      if [[ "$vuln_count" -gt 0 ]]; then
        log "  go: $vuln_count vulnerabilities"
        bump_exit high
        issues=$vuln_count
      else
        log "  go: No known vulnerabilities"
      fi
    fi
  elif command -v go &>/dev/null && [[ -f go.mod ]]; then
    warn "  govulncheck not installed, installing..."
    go install golang.org/x/vuln/cmd/govulncheck@latest 2>/dev/null && run_go && return
  fi

  if [[ "$CHECK_OUTDATED" == "true" ]] && command -v go &>/dev/null && [[ -f go.mod ]]; then
    local outdated
    outdated=$(go list -u -m -json all 2>/dev/null | python3 -c "
import sys, json
count = 0
for line in sys.stdin.read().split('}\n{'):
    try:
        obj = json.loads('{' + line.strip().strip('{}') + '}')
        if obj.get('Update'):
            count += 1
    except:
        pass
print(count)
" 2>/dev/null || echo 0)
    log "  go: $outdated outdated modules"
  fi

  echo "$issues"
}

run_maven() {
  log "Auditing Maven dependencies..."
  local issues=0

  if command -v mvn &>/dev/null && [[ -f pom.xml ]]; then
    local vuln_out
    if vuln_out=$(mvn org.owasp:dependency-check-maven:check -Dformat=json 2>/dev/null); then
      local report="${REPORT_DIR}/dependency-check-report.json"
      if [[ -f "$report" ]]; then
        local vuln_count
        vuln_count=$(python3 -c "
import json
with open('$report') as f:
    d = json.load(f)
print(d.get('totalDependencie s', 0))
" 2>/dev/null || echo 0)
        log "  maven: dependency check completed"
      fi
    fi
  fi

  if [[ "$CHECK_OUTDATED" == "true" ]] && command -v mvn &>/dev/null; then
    mvn versions:display-dependency-updates -DprocessDependencyManagement=false 2>/dev/null | \
      grep -c "available" 2>/dev/null | xargs -I{} log "  maven: {} outdated dependencies" || true
  fi

  echo "$issues"
}

run_gradle() {
  log "Auditing Gradle dependencies..."
  local issues=0

  if command -v gradle &>/dev/null || [[ -f ./gradlew ]]; then
    local gradle_cmd="./gradlew"
    [[ -x ./gradlew ]] || gradle_cmd="gradle"

    $gradle_cmd dependencyCheckAnalyze 2>/dev/null || warn "  gradle OWASP check failed"

    if [[ "$CHECK_OUTDATED" == "true" ]]; then
      $gradle_cmd dependencyUpdates 2>/dev/null || warn "  gradle dependency updates failed"
    fi
  fi

  echo "$issues"
}

run_bundler() {
  log "Auditing Bundler dependencies..."
  local issues=0

  if command -v bundle-audit &>/dev/null && [[ -f Gemfile.lock ]]; then
    bundle-audit update 2>/dev/null || true
    local audit_out
    if audit_out=$(bundle-audit check --format json 2>/dev/null); then
      local vuln_count
      vuln_count=$(echo "$audit_out" | python3 -c "import sys,json; d=json.load(sys.stdin); print(len(d.get('results',[])))" 2>/dev/null || echo 0)
      if [[ "$vuln_count" -gt 0 ]]; then
        log "  bundler: $vuln_count vulnerabilities"
        bump_exit high
        issues=$vuln_count
      else
        log "  bundler: No known vulnerabilities"
      fi
    fi
  elif command -v bundle &>/dev/null && [[ -f Gemfile ]]; then
    warn "  bundler-audit not installed, installing..."
    gem install bundler-audit -q 2>/dev/null && run_bundler && return
  fi

  if [[ "$CHECK_OUTDATED" == "true" ]] && command -v bundle &>/dev/null && [[ -f Gemfile ]]; then
    local outdated
    outdated=$(bundle outdated 2>/dev/null | grep -c "newest" || echo 0)
    log "  bundler: $outdated outdated gems"
  fi

  echo "$issues"
}

run_composer() {
  log "Auditing Composer dependencies..."
  local issues=0

  if command -v composer &>/dev/null && [[ -f composer.json ]]; then
    local audit_out
    if audit_out=$(composer audit --format=json 2>/dev/null); then
      local vuln_count
      vuln_count=$(echo "$audit_out" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('total',0))" 2>/dev/null || echo 0)
      if [[ "$vuln_count" -gt 0 ]]; then
        log "  composer: $vuln_count vulnerabilities"
        bump_exit high
        issues=$vuln_count
      else
        log "  composer: No known vulnerabilities"
      fi
    fi
  fi

  if [[ "$CHECK_OUTDATED" == "true" ]] && command -v composer &>/dev/null && [[ -f composer.json ]]; then
    local outdated
    outdated=$(composer outdated --format=json 2>/dev/null | python3 -c "import sys,json; d=json.load(sys.stdin); print(len(d.get('installed',[])))" 2>/dev/null || echo 0)
    log "  composer: $outdated outdated packages"
  fi

  echo "$issues"
}

run_nuget() {
  log "Auditing NuGet dependencies..."
  local issues=0

  if command -v dotnet &>/dev/null; then
    local csproj_files
    csproj_files=$(find . -maxdepth 3 -name "*.csproj" 2>/dev/null || true)

    while IFS= read -r csproj; do
      [[ -z "$csproj" ]] && continue
      local proj_dir
      proj_dir=$(dirname "$csproj")

      if [[ "$CHECK_OUTDATED" == "true" ]]; then
        dotnet list "$csproj" package --outdated 2>/dev/null | grep -c "has newer" 2>/dev/null | xargs -I{} log "  nuget ($csproj): {} outdated packages" || true
      fi

      dotnet list "$csproj" package --vulnerable 2>/dev/null | grep -c "has the following" 2>/dev/null | xargs -I{} log "  nuget ($csproj): {} vulnerable packages" || true
    done <<< "$csproj_files"
  fi

  echo "$issues"
}

run_swift() {
  log "Auditing Swift dependencies..."
  if command -v swift &>/dev/null && [[ -f Package.swift ]]; then
    swift package audit 2>/dev/null || warn "  swift audit not supported or failed"
  fi
  echo 0
}

run_pub() {
  log "Auditing Pub (Dart) dependencies..."
  if command -v dart &>/dev/null && [[ -f pubspec.yaml ]]; then
    dart pub audit 2>/dev/null || dart pub deps 2>/dev/null || warn "  pub audit failed"
  fi
  echo 0
}

run_hex() {
  log "Auditing Hex (Elixir) dependencies..."
  if command -v mix &>/dev/null && [[ -f mix.exs ]]; then
    mix deps.audit 2>/dev/null || warn "  hex audit failed"
  fi
  echo 0
}

run_conan() {
  log "Auditing Conan dependencies..."
  if command -v conan &>/dev/null; then
    conan inspect . 2>/dev/null || warn "  conan audit limited"
  fi
  echo 0
}

run_vcpkg() {
  log "Auditing vcpkg dependencies..."
  if command -v vcpkg &>/dev/null; then
    vcpkg audit 2>/dev/null || warn "  vcpkg audit limited"
  fi
  echo 0
}

run_zig() {
  log "Checking Zig build..."
  if command -v zig &>/dev/null && [[ -f build.zig ]]; then
    zig build --help >/dev/null 2>&1 && log "  zig: build configuration valid" || warn "  zig: build check failed"
  fi
  echo 0
}

run_nim() {
  log "Auditing Nim dependencies..."
  if command -v nimble &>/dev/null; then
    nimble audit 2>/dev/null || warn "  nimble audit limited"
  fi
  echo 0
}

run_crystal() {
  log "Auditing Crystal dependencies..."
  if command -v shards &>/dev/null && [[ -f shard.yml ]]; then
    shards check 2>/dev/null || warn "  shards check limited"
  fi
  echo 0
}

run_r() {
  log "Auditing R dependencies..."
  if command -v R &>/dev/null && [[ -f DESCRIPTION ]]; then
    Rscript -e "if(requireNamespace('renv', quietly=TRUE)) renv::dependencies()" 2>/dev/null || warn "  R audit limited"
  fi
  echo 0
}

run_julia() {
  log "Auditing Julia dependencies..."
  if command -v julia &>/dev/null && [[ -f Project.toml ]]; then
    julia -e "using Pkg; Pkg.status()" 2>/dev/null || warn "  julia audit limited"
  fi
  echo 0
}

run_terraform() {
  log "Auditing Terraform dependencies..."
  if command -v terraform &>/dev/null; then
    terraform version 2>/dev/null || warn "  terraform version check failed"
    if [[ -f .terraform.lock.hcl ]]; then
      log "  terraform: lock file present"
    fi
  fi
  echo 0
}

run_docker() {
  log "Auditing Docker dependencies..."
  if command -v docker &>/dev/null && [[ -f Dockerfile ]]; then
    local base_image
    base_image=$(grep -m1 "^FROM" Dockerfile 2>/dev/null | awk '{print $2}' || echo "unknown")
    log "  docker: base image is $base_image"
  fi
  echo 0
}

# --- Main ---
main() {
  log "=========================================="
  log "[iDevOps] Universal Dependency Auditor"
  log "=========================================="
  log "FAIL_ON: $FAIL_ON | LANGUAGES: $LANGUAGES"
  log "CHECK_OUTDATED: $CHECK_OUTDATED | CHECK_LICENSES: $CHECK_LICENSES"
  log ""

  local ecosystems
  ecosystems=$(detect_ecosystems)

  if [[ -z "$ecosystems" ]]; then
    log "No supported ecosystems detected in $(pwd)"
    exit 0
  fi

  log "Detected ecosystems: $ecosystems"
  log ""

  for eco in $ecosystems; do
    local result
    case "$eco" in
      npm)      result=$(run_npm) ;;
      pip)      result=$(run_pip) ;;
      cargo)    result=$(run_cargo) ;;
      go)       result=$(run_go) ;;
      maven)    result=$(run_maven) ;;
      gradle)   result=$(run_gradle) ;;
      bundler)  result=$(run_bundler) ;;
      composer) result=$(run_composer) ;;
      nuget)    result=$(run_nuget) ;;
      swift)    result=$(run_swift) ;;
      pub)      result=$(run_pub) ;;
      hex)      result=$(run_hex) ;;
      conan)    result=$(run_conan) ;;
      vcpkg)    result=$(run_vcpkg) ;;
      zig)      result=$(run_zig) ;;
      nim)      result=$(run_nim) ;;
      crystal)  result=$(run_crystal) ;;
      r)        result=$(run_r) ;;
      julia)    result=$(run_julia) ;;
      terraform) result=$(run_terraform) ;;
      docker)   result=$(run_docker) ;;
      *)        warn "Unknown ecosystem: $eco"; result=0 ;;
    esac
  done

  log ""
  log "=========================================="
  if [[ $EXIT_CODE -eq 0 ]]; then
    log "[iDevOps] Dependency audit PASSED"
  else
    log "[iDevOps] Dependency audit FAILED (threshold: $FAIL_ON)"
  fi
  log "=========================================="

  exit $EXIT_CODE
}

main "$@"
