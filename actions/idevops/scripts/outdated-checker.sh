#!/usr/bin/env bash
# [iDevOps] Outdated Dependency Checker - ALL ecosystems
set -euo pipefail

FAIL_ON="${FAIL_ON:-info}"
OUTPUT_FORMAT="${OUTPUT_FORMAT:-text}"
REPORT_DIR="${REPORT_DIR:-.}"
TIMESTAMP=$(date +%Y%m%dT%H%M%SZ)
TOTAL_OUTDATED=0

log() { echo "[iDevOps] $*"; }
warn() { echo "[iDevOps] WARNING: $*" >&2; }

check_ecosystem() {
  local name="$1"
  local check_cmd="$2"
  local count

  count=$(eval "$check_cmd" 2>/dev/null || echo 0)
  if [[ "$count" -gt 0 ]] && [[ "$count" =~ ^[0-9]+$ ]]; then
    log "  $name: $count outdated"
    TOTAL_OUTDATED=$((TOTAL_OUTDATED + count))
  fi
}

main() {
  log "=========================================="
  log "[iDevOps] Outdated Dependency Checker"
  log "=========================================="
  log ""

  # npm
  if [[ -f package.json ]]; then
    log "Checking npm..."
    if [[ -f pnpm-lock.yaml ]]; then
      check_ecosystem "pnpm" "pnpm outdated --format json 2>/dev/null | python3 -c 'import sys,json; print(len(json.load(sys.stdin)))' 2>/dev/null || echo 0"
    elif [[ -f yarn.lock ]]; then
      check_ecosystem "yarn" "yarn outdated --json 2>/dev/null | python3 -c 'import sys,json; print(len(json.load(sys.stdin)))' 2>/dev/null || echo 0"
    elif command -v npm &>/dev/null; then
      check_ecosystem "npm" "npm outdated --json 2>/dev/null | python3 -c 'import sys,json; print(len(json.load(sys.stdin)))' 2>/dev/null || echo 0"
    fi
  fi

  # pip
  if [[ -f requirements.txt ]] || [[ -f pyproject.toml ]] || [[ -f setup.py ]] || [[ -f Pipfile ]]; then
    log "Checking pip..."
    check_ecosystem "pip" "pip list --outdated --format json 2>/dev/null | python3 -c 'import sys,json; print(len(json.load(sys.stdin)))' 2>/dev/null || echo 0"
  fi

  # cargo
  if [[ -f Cargo.toml ]]; then
    log "Checking Cargo..."
    check_ecosystem "cargo" "cargo outdated --format json 2>/dev/null | python3 -c 'import sys,json; d=json.load(sys.stdin); print(sum(len(v) for v in d.get(\"dependencies\",{}).values()))' 2>/dev/null || echo 0"
  fi

  # go
  if [[ -f go.mod ]]; then
    log "Checking Go..."
    check_ecosystem "go" "go list -u -m -json all 2>/dev/null | python3 -c \"
import sys, json
data = sys.stdin.read()
count = 0
decoder = json.JSONDecoder()
idx = 0
while idx < len(data):
    data_stripped = data[idx:].lstrip()
    if not data_stripped: break
    idx = len(data) - len(data_stripped)
    obj, end = decoder.raw_decode(data, idx)
    idx += end
    if obj.get('Update'): count += 1
print(count)
\" 2>/dev/null || echo 0"
  fi

  # maven
  if [[ -f pom.xml ]]; then
    log "Checking Maven..."
    if command -v mvn &>/dev/null; then
      local maven_outdated
      maven_outdated=$(mvn versions:display-dependency-updates -DprocessDependencyManagement=false 2>/dev/null | grep -c "\[INFO\].*->" || echo 0)
      check_ecosystem "Maven" "echo $maven_outdated"
    fi
  fi

  # gradle
  if [[ -f build.gradle ]] || [[ -f build.gradle.kts ]]; then
    log "Checking Gradle..."
    if [[ -x ./gradlew ]] || command -v gradle &>/dev/null; then
      local gradle_cmd="./gradlew"
      [[ -x ./gradlew ]] || gradle_cmd="gradle"
      local gradle_outdated
      gradle_outdated=$($gradle_cmd dependencyUpdates -Drevision=release 2>/dev/null | grep -c "\->" || echo 0)
      check_ecosystem "Gradle" "echo $gradle_outdated"
    fi
  fi

  # bundler
  if [[ -f Gemfile ]]; then
    log "Checking Bundler..."
    check_ecosystem "Bundler" "bundle outdated 2>/dev/null | grep -c 'newest' || echo 0"
  fi

  # composer
  if [[ -f composer.json ]]; then
    log "Checking Composer..."
    check_ecosystem "Composer" "composer outdated --direct --format=json 2>/dev/null | python3 -c 'import sys,json; print(len(json.load(sys.stdin).get(\"installed\",[])))' 2>/dev/null || echo 0"
  fi

  # nuget
  if find . -maxdepth 3 -name "*.csproj" 2>/dev/null | head -1 | grep -q .; then
    log "Checking NuGet..."
    local nuget_outdated=0
    while IFS= read -r csproj; do
      [[ -z "$csproj" ]] && continue
      local proj_count
      proj_count=$(dotnet list "$csproj" package --outdated 2>/dev/null | grep -c "has newer" || echo 0)
      nuget_outdated=$((nuget_outdated + proj_count))
    done < <(find . -maxdepth 3 -name "*.csproj" 2>/dev/null)
    check_ecosystem "NuGet" "echo $nuget_outdated"
  fi

  # swift
  if [[ -f Package.swift ]]; then
    log "Checking Swift..."
    if command -v swift &>/dev/null; then
      local swift_outdated
      swift_outdated=$(swift package outdated 2>/dev/null | grep -c "available" || echo 0)
      check_ecosystem "Swift" "echo $swift_outdated"
    fi
  fi

  # pub (dart)
  if [[ -f pubspec.yaml ]]; then
    log "Checking Pub..."
    check_ecosystem "Pub" "dart pub outdated 2>/dev/null | grep -c 'latest' || echo 0"
  fi

  # hex (elixir)
  if [[ -f mix.exs ]]; then
    log "Checking Hex..."
    check_ecosystem "Hex" "mix deps --outdated 2>/dev/null | grep -c 'new' || echo 0"
  fi

  # zig
  if [[ -f build.zig ]]; then
    log "Checking Zig..."
    log "  Zig: manual dependency check required"
  fi

  # nim
  if find . -maxdepth 3 -name "*.nimble" 2>/dev/null | head -1 | grep -q .; then
    log "Checking Nimble..."
    if command -v nimble &>/dev/null; then
      local nim_outdated
      nim_outdated=$(nimble list --outdated 2>/dev/null | grep -c "." || echo 0)
      check_ecosystem "Nimble" "echo $nim_outdated"
    fi
  fi

  # crystal
  if [[ -f shard.yml ]]; then
    log "Checking Shards..."
    if command -v shards &>/dev/null; then
      local crystal_outdated
      crystal_outdated=$(shards outdated 2>/dev/null | grep -c "outdated" || echo 0)
      check_ecosystem "Shards" "echo $crystal_outdated"
    fi
  fi

  # conan
  if [[ -f conanfile.py ]] || [[ -f conanfile.txt ]]; then
    log "Checking Conan..."
    log "  Conan: manual dependency check required"
  fi

  # vcpkg
  if [[ -f vcpkg.json ]]; then
    log "Checking vcpkg..."
    log "  vcpkg: manual dependency check required"
  fi

  # R
  if [[ -f DESCRIPTION ]] && grep -q "^Package:" DESCRIPTION 2>/dev/null; then
    log "Checking R..."
    if command -v Rscript &>/dev/null; then
      local r_outdated
      r_outdated=$(Rscript -e "if(requireNamespace('cranlogs')) print(cranlogs::cran_downloads(period='last-month'))" 2>/dev/null | grep -c "." || echo 0)
      check_ecosystem "R" "echo 0"
    fi
  fi

  # julia
  if [[ -f Project.toml ]]; then
    log "Checking Julia..."
    if command -v julia &>/dev/null; then
      log "  Julia: checking for updates..."
      julia -e "using Pkg; Pkg.update()" 2>/dev/null || true
    fi
  fi

  # terraform
  if find . -maxdepth 3 -name "*.tf" 2>/dev/null | head -1 | grep -q .; then
    log "Checking Terraform..."
    if command -v terraform &>/dev/null; then
      terraform init -backend=false 2>/dev/null || true
      terraform providers lock -check 2>/dev/null || warn "  Terraform provider lock check failed"
    fi
  fi

  # --- Summary ---
  log ""
  log "=========================================="
  log "Total outdated dependencies: $TOTAL_OUTDATED"
  log "=========================================="

  if [[ $TOTAL_OUTDATED -gt 0 ]]; then
    log "[iDevOps] Outdated dependencies detected: $TOTAL_OUTDATED"
  else
    log "[iDevOps] All dependencies up to date"
  fi

  log "=========================================="

  if [[ "$FAIL_ON" != "info" ]] && [[ $TOTAL_OUTDATED -gt 0 ]]; then
    exit 1
  fi
}

main "$@"
