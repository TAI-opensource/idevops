#!/usr/bin/env bash
# [iDevOps] Detect project languages and tools
# Analyzes the repository and outputs which checks should run
# Sets IDEVOPS_HAS_* environment variables for conditional steps

set -euo pipefail

echo "::group::[iDevOps] Detecting project type"

DETECTED=""
HAS_PACKAGE_JSON=false
HAS_REQUIREMENTS=false
HAS_CARGO_TOML=false
HAS_GO_MOD=false
HAS_POM_XML=false
HAS_BUILD_GRADLE=false
HAS_GEMFILE=false
HAS_COMPOSER_JSON=false
HAS_CSPROJ=false
HAS_PACKAGE_SWIFT=false
HAS_BUILD_SBT=false
HAS_MIX_EXS=false
HAS_PUBSPEC=false
HAS_STACK_YAML=false
HAS_LUA_ROCKS=false
HAS_CPMETA=false
HAS_R_PROJECT=false
HAS_JULIA_TOML=false
HAS_PSP1=false
HAS_DOCKERFILE=false
HAS_TERRAFORM=false
HAS_KUBERNETES=false
HAS_HELM=false
HAS_ANSIBLE=false
HAS_CLOUDFORMATION=false
HAS_GRAPHQL=false
HAS_PROTOBUF=false
HAS_SQL=false
HAS_CSS=false
HAS_HTML=false
HAS_YAML=false
HAS_JSON=false
HAS_MARKDOWN=false
HAS_DOCKER_COMPOSE=false

# Detect by config files
[ -f "package.json" ] && HAS_PACKAGE_JSON=true && DETECTED="$DETECTED javascript,"
[ -f "requirements.txt" ] || [ -f "pyproject.toml" ] || [ -f "setup.py" ] || [ -f "Pipfile" ] && HAS_REQUIREMENTS=true && DETECTED="$DETECTED python,"
[ -f "Cargo.toml" ] && HAS_CARGO_TOML=true && DETECTED="$DETECTED rust,"
[ -f "go.mod" ] && HAS_GO_MOD=true && DETECTED="$DETECTED go,"
[ -f "pom.xml" ] || [ -f "build.gradle" ] || [ -f "build.gradle.kts" ] && HAS_POM_XML=true && DETECTED="$DETECTED java,"
[ -f "Gemfile" ] && HAS_GEMFILE=true && DETECTED="$DETECTED ruby,"
[ -f "composer.json" ] && HAS_COMPOSER_JSON=true && DETECTED="$DETECTED php,"
[ -f "*.csproj" ] || [ -f "*.sln" ] && HAS_CSPROJ=true && DETECTED="$DETECTED csharp,"
[ -f "Package.swift" ] && HAS_PACKAGE_SWIFT=true && DETECTED="$DETECTED swift,"
[ -f "build.sbt" ] && HAS_BUILD_SBT=true && DETECTED="$DETECTED scala,"
[ -f "mix.exs" ] && HAS_MIX_EXS=true && DETECTED="$DETECTED elixir,"
[ -f "pubspec.yaml" ] && HAS_PUBSPEC=true && DETECTED="$DETECTED dart,"
[ -f "stack.yaml" ] && HAS_STACK_YAML=true && DETECTED="$DETECTED haskell,"
[ -f "RProject.toml" ] || [ -f ".Rprofile" ] && HAS_R_PROJECT=true && DETECTED="$DETECTED r,"
[ -f "Project.toml" ] || [ -f "Manifest.toml" ] && HAS_JULIA_TOML=true && DETECTED="$DETECTED julia,"
[ -f "*.ps1" ] || [ -f "profile.ps1" ] && HAS_PSP1=true && DETECTED="$DETECTED powershell,"

# Detect by file extensions
JS_COUNT=$(find . -maxdepth 5 -name "*.js" -o -name "*.jsx" -o -name "*.ts" -o -name "*.tsx" -o -name "*.mjs" -o -name "*.cjs" 2>/dev/null | head -1 | wc -l)
[ "$JS_COUNT" -gt 0 ] && HAS_PACKAGE_JSON=true && [[ "$DETECTED" != *"javascript"* ]] && DETECTED="$DETECTED javascript,"

PY_COUNT=$(find . -maxdepth 5 -name "*.py" 2>/dev/null | head -1 | wc -l)
[ "$PY_COUNT" -gt 0 ] && HAS_REQUIREMENTS=true && [[ "$DETECTED" != *"python"* ]] && DETECTED="$DETECTED python,"

RUST_COUNT=$(find . -maxdepth 5 -name "*.rs" 2>/dev/null | head -1 | wc -l)
[ "$RUST_COUNT" -gt 0 ] && HAS_CARGO_TOML=true && [[ "$DETECTED" != *"rust"* ]] && DETECTED="$DETECTED rust,"

GO_COUNT=$(find . -maxdepth 5 -name "*.go" 2>/dev/null | head -1 | wc -l)
[ "$GO_COUNT" -gt 0 ] && HAS_GO_MOD=true && [[ "$DETECTED" != *"go"* ]] && DETECTED="$DETECTED go,"

JAVA_COUNT=$(find . -maxdepth 5 -name "*.java" 2>/dev/null | head -1 | wc -l)
[ "$JAVA_COUNT" -gt 0 ] && HAS_POM_XML=true && [[ "$DETECTED" != *"java"* ]] && DETECTED="$DETECTED java,"

KOTLIN_COUNT=$(find . -maxdepth 5 -name "*.kt" -o -name "*.kts" 2>/dev/null | head -1 | wc -l)
[ "$KOTLIN_COUNT" -gt 0 ] && [[ "$DETECTED" != *"java"* ]] && DETECTED="$DETECTED java,"

CPP_COUNT=$(find . -maxdepth 5 -name "*.c" -o -name "*.cpp" -o -name "*.cc" -o -name "*.h" -o -name "*.hpp" 2>/dev/null | head -1 | wc -l)
[ "$CPP_COUNT" -gt 0 ] && DETECTED="$DETECTED c_cpp,"

CSHARP_COUNT=$(find . -maxdepth 5 -name "*.cs" 2>/dev/null | head -1 | wc -l)
[ "$CSHARP_COUNT" -gt 0 ] && HAS_CSPROJ=true && [[ "$DETECTED" != *"csharp"* ]] && DETECTED="$DETECTED csharp,"

RUBY_COUNT=$(find . -maxdepth 5 -name "*.rb" 2>/dev/null | head -1 | wc -l)
[ "$RUBY_COUNT" -gt 0 ] && HAS_GEMFILE=true && [[ "$DETECTED" != *"ruby"* ]] && DETECTED="$DETECTED ruby,"

PHP_COUNT=$(find . -maxdepth 5 -name "*.php" 2>/dev/null | head -1 | wc -l)
[ "$PHP_COUNT" -gt 0 ] && HAS_COMPOSER_JSON=true && [[ "$DETECTED" != *"php"* ]] && DETECTED="$DETECTED php,"

SWIFT_COUNT=$(find . -maxdepth 5 -name "*.swift" 2>/dev/null | head -1 | wc -l)
[ "$SWIFT_COUNT" -gt 0 ] && [[ "$DETECTED" != *"swift"* ]] && DETECTED="$DETECTED swift,"

SCALA_COUNT=$(find . -maxdepth 5 -name "*.scala" 2>/dev/null | head -1 | wc -l)
[ "$SCALA_COUNT" -gt 0 ] && [[ "$DETECTED" != *"scala"* ]] && DETECTED="$DETECTED scala,"

ELIXIR_COUNT=$(find . -maxdepth 5 -name "*.ex" -o -name "*.exs" 2>/dev/null | head -1 | wc -l)
[ "$ELIXIR_COUNT" -gt 0 ] && [[ "$DETECTED" != *"elixir"* ]] && DETECTED="$DETECTED elixir,"

DART_COUNT=$(find . -maxdepth 5 -name "*.dart" 2>/dev/null | head -1 | wc -l)
[ "$DART_COUNT" -gt 0 ] && HAS_PUBSPEC=true && [[ "$DETECTED" != *"dart"* ]] && DETECTED="$DETECTED dart,"

HASKELL_COUNT=$(find . -maxdepth 5 -name "*.hs" -o -name "*.lhs" 2>/dev/null | head -1 | wc -l)
[ "$HASKELL_COUNT" -gt 0 ] && [[ "$DETECTED" != *"haskell"* ]] && DETECTED="$DETECTED haskell,"

LUA_COUNT=$(find . -maxdepth 5 -name "*.lua" 2>/dev/null | head -1 | wc -l)
[ "$LUA_COUNT" -gt 0 ] && DETECTED="$DETECTED lua,"

PERL_COUNT=$(find . -maxdepth 5 -name "*.pl" -o -name "*.pm" 2>/dev/null | head -1 | wc -l)
[ "$PERL_COUNT" -gt 0 ] && DETECTED="$DETECTED perl,"

R_COUNT=$(find . -maxdepth 5 -name "*.R" -o -name "*.r" 2>/dev/null | head -1 | wc -l)
[ "$R_COUNT" -gt 0 ] && [[ "$DETECTED" != *"r,"* ]] && DETECTED="$DETECTED r,"

JULIA_COUNT=$(find . -maxdepth 5 -name "*.jl" 2>/dev/null | head -1 | wc -l)
[ "$JULIA_COUNT" -gt 0 ] && [[ "$DETECTED" != *"julia"* ]] && DETECTED="$DETECTED julia,"

SQL_COUNT=$(find . -maxdepth 5 -name "*.sql" 2>/dev/null | head -1 | wc -l)
[ "$SQL_COUNT" -gt 0 ] && HAS_SQL=true && DETECTED="$DETECTED sql,"

GRAPHQL_COUNT=$(find . -maxdepth 5 -name "*.graphql" -o -name "*.gql" 2>/dev/null | head -1 | wc -l)
[ "$GRAPHQL_COUNT" -gt 0 ] && HAS_GRAPHQL=true && DETECTED="$DETECTED graphql,"

PROTO_COUNT=$(find . -maxdepth 5 -name "*.proto" 2>/dev/null | head -1 | wc -l)
[ "$PROTO_COUNT" -gt 0 ] && HAS_PROTOBUF=true && DETECTED="$DETECTED protobuf,"

CSS_COUNT=$(find . -maxdepth 5 -name "*.css" -o -name "*.scss" -o -name "*.less" 2>/dev/null | head -1 | wc -l)
[ "$CSS_COUNT" -gt 0 ] && HAS_CSS=true && DETECTED="$DETECTED css,"

HTML_COUNT=$(find . -maxdepth 5 -name "*.html" -o -name "*.htm" -o -name "*.vue" -o -name "*.svelte" 2>/dev/null | head -1 | wc -l)
[ "$HTML_COUNT" -gt 0 ] && HAS_HTML=true && DETECTED="$DETECTED html,"

# Detect infrastructure
[ -f "Dockerfile" ] || [ -f "docker-compose.yml" ] || [ -f "docker-compose.yaml" ] || find . -maxdepth 3 -name "Dockerfile" 2>/dev/null | head -1 | grep -q . && HAS_DOCKERFILE=true && DETECTED="$DETECTED docker,"

TF_COUNT=$(find . -maxdepth 5 -name "*.tf" 2>/dev/null | head -1 | wc -l)
[ "$TF_COUNT" -gt 0 ] && HAS_TERRAFORM=true && DETECTED="$DETECTED terraform,"

K8S_COUNT=$(find . -maxdepth 5 \( -name "*.yaml" -o -name "*.yml" \) -exec grep -l "apiVersion:" {} + 2>/dev/null | head -1 | wc -l)
[ "$K8S_COUNT" -gt 0 ] && HAS_KUBERNETES=true && DETECTED="$DETECTED kubernetes,"

[ -f "Chart.yaml" ] && HAS_HELM=true && DETECTED="$DETECTED helm,"

[ -f "playbook.yml" ] || [ -f "playbook.yaml" ] || [ -d "roles" ] && HAS_ANSIBLE=true && DETECTED="$DETECTED ansible,"

CF_COUNT=$(find . -maxdepth 5 -name "*.yaml" -o -name "*.yml" -o -name "*.json" -o -name "*.template" 2>/dev/null -exec grep -l "AWSTemplateFormatVersion" {} + 2>/dev/null | head -1 | wc -l)
[ "$CF_COUNT" -gt 0 ] && HAS_CLOUDFORMATION=true && DETECTED="$DETECTED cloudformation,"

# Detect YAML/JSON/Markdown (always check if present)
YAML_COUNT=$(find . -maxdepth 3 -name "*.yaml" -o -name "*.yml" 2>/dev/null | head -1 | wc -l)
[ "$YAML_COUNT" -gt 0 ] && HAS_YAML=true

JSON_COUNT=$(find . -maxdepth 3 -name "*.json" 2>/dev/null | head -1 | wc -l)
[ "$JSON_COUNT" -gt 0 ] && HAS_JSON=true

MD_COUNT=$(find . -maxdepth 3 -name "*.md" 2>/dev/null | head -1 | wc -l)
[ "$MD_COUNT" -gt 0 ] && HAS_MARKDOWN=true

# Remove trailing comma
DETECTED="${DETECTED%,}"

# Output as GitHub Actions outputs
{
  echo "has_javascript=$( echo "$DETECTED" | grep -q javascript && echo true || echo false )"
  echo "has_python=$( echo "$DETECTED" | grep -q python && echo true || echo false )"
  echo "has_rust=$( echo "$DETECTED" | grep -q rust && echo true || echo false )"
  echo "has_go=$( echo "$DETECTED" | grep -q go && echo true || echo false )"
  echo "has_java=$( echo "$DETECTED" | grep -q java && echo true || echo false )"
  echo "has_c_cpp=$( echo "$DETECTED" | grep -q c_cpp && echo true || echo false )"
  echo "has_csharp=$( echo "$DETECTED" | grep -q csharp && echo true || echo false )"
  echo "has_ruby=$( echo "$DETECTED" | grep -q ruby && echo true || echo false )"
  echo "has_php=$( echo "$DETECTED" | grep -q php && echo true || echo false )"
  echo "has_swift=$( echo "$DETECTED" | grep -q swift && echo true || echo false )"
  echo "has_scala=$( echo "$DETECTED" | grep -q scala && echo true || echo false )"
  echo "has_haskell=$( echo "$DETECTED" | grep -q haskell && echo true || echo false )"
  echo "has_elixir=$( echo "$DETECTED" | grep -q elixir && echo true || echo false )"
  echo "has_dart=$( echo "$DETECTED" | grep -q dart && echo true || echo false )"
  echo "has_lua=$( echo "$DETECTED" | grep -q lua && echo true || echo false )"
  echo "has_perl=$( echo "$DETECTED" | grep -q perl && echo true || echo false )"
  echo "has_r=$( echo "$DETECTED" | grep -q ",r," && echo true || echo false )"
  echo "has_julia=$( echo "$DETECTED" | grep -q julia && echo true || echo false )"
  echo "has_powershell=$( echo "$DETECTED" | grep -q powershell && echo true || echo false )"
  echo "has_sql=$( echo "$DETECTED" | grep -q sql && echo true || echo false )"
  echo "has_graphql=$( echo "$DETECTED" | grep -q graphql && echo true || echo false )"
  echo "has_protobuf=$( echo "$DETECTED" | grep -q protobuf && echo true || echo false )"
  echo "has_css=$( echo "$DETECTED" | grep -q css && echo true || echo false )"
  echo "has_html=$( echo "$DETECTED" | grep -q html && echo true || echo false )"
  echo "has_yaml=$HAS_YAML"
  echo "has_json=$HAS_JSON"
  echo "has_markdown=$HAS_MARKDOWN"
  echo "has_docker=$( echo "$DETECTED" | grep -q docker && echo true || echo false )"
  echo "has_terraform=$( echo "$DETECTED" | grep -q terraform && echo true || echo false )"
  echo "has_kubernetes=$( echo "$DETECTED" | grep -q kubernetes && echo true || echo false )"
  echo "has_helm=$( echo "$DETECTED" | grep -q helm && echo true || echo false )"
  echo "has_ansible=$( echo "$DETECTED" | grep -q ansible && echo true || echo false )"
} >> "$GITHUB_OUTPUT"

echo "Detected: $DETECTED"
echo "::endgroup::"
