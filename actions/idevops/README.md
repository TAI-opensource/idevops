# iDevOps -- All-in-One DevOps Pipeline

> **The most comprehensive DevOps pipeline ever created.** One GitHub Action that replaces 30+ separate tools with a single, unified step.

[![GitHub Actions](https://img.shields.io/badge/GitHub%20Actions-Ready-blue?logo=githubactions)](https://github.com/features/actions)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](https://opensource.org/licenses/MIT)
[![PRs Welcome](https://img.shields.io/badge/PRs-Welcome-brightgreen.svg)](https://github.com/TAI-opensource/idevops/pulls)

---

## Why iDevOps?

Managing a modern DevOps pipeline means stitching together dozens of separate tools, each with its own configuration, learning curve, and maintenance burden. iDevOps eliminates that complexity with a single, unified action.

### iDevOps vs. Traditional Tooling

| Capability               | iDevOps                                                       | Without iDevOps                                         |
| ------------------------ | ------------------------------------------------------------- | ------------------------------------------------------- |
| SAST Scanning            | Built-in (Semgrep, Bandit, Brakeman, Gosec, FindSecBugs, PMD) | Semgrep + Bandit + Brakeman + Gosec + FindSecBugs + PMD |
| SCA Scanning             | Built-in (Trivy, OSV-Scanner, Grype)                          | Trivy + OSV-Scanner + Grype                             |
| Secret Detection         | Built-in (Gitleaks, TruffleHog, detect-secrets)               | Gitleaks + TruffleHog + detect-secrets                  |
| Container Security       | Built-in (Hadolint, Dockle, Trivy image scan)                 | Hadolint + Dockle + Trivy image + Trivy container       |
| IaC Scanning             | Built-in (Checkov, TFLint, KICS, Trivy config)                | Checkov + TFLint + KICS + Trivy config                  |
| DAST Scanning            | Built-in (OWASP ZAP, Nuclei, httpx, gospider)                 | ZAP + Nuclei + httpx + gospider                         |
| Recon                    | Built-in (subfinder, naabu, httpx, nuclei)                    | subfinder + naabu + httpx + nuclei                      |
| Linting (34+ languages)  | Built-in                                                      | ESLint + Ruff + Clippy + Hadolint + 30+ more            |
| Dependency Audit         | Built-in (21+ ecosystems)                                     | npm audit + pip-audit + cargo-audit + 18+ more          |
| License Compliance       | Built-in (FOSSA, ScanCode, per-ecosystem)                     | FOSSA or ScanCode + per-ecosystem tools                 |
| SBOM Generation          | Built-in (CycloneDX + SPDX via Syft)                          | Syft separately                                         |
| CodeQL Analysis          | Built-in                                                      | CodeQL action separately                                |
| Outdated Checker         | Built-in                                                      | npm outdated + pip list --outdated + more               |
| Quality Metrics          | Built-in                                                      | SonarQube Community or custom scripts                   |
| SARIF Upload             | Built-in                                                      | Manual upload-sarif step                                |
| Health Score             | Built-in                                                      | Custom script needed                                    |
| **Total tools required** | **1 action**                                                  | **30+ tools**                                           |

### The Cost of Tool Sprawl

| Metric               | Without iDevOps | With iDevOps        |
| -------------------- | --------------- | ------------------- |
| Workflow steps       | 15-30 steps     | 1 step              |
| Configuration files  | 10+ files       | 1 file              |
| Maintenance overhead | High            | Minimal             |
| Onboarding time      | Days            | Minutes             |
| Consistent reporting | No              | Yes (unified SARIF) |
| Language support     | Per-tool basis  | 34+ languages       |

---

## Features

### Security Scanning

| Category      | Tools                                                      | What It Does                                                                |
| ------------- | ---------------------------------------------------------- | --------------------------------------------------------------------------- |
| **SAST**      | Semgrep, Bandit, Brakeman, Gosec, FindSecBugs, PMD, CodeQL | Static analysis for source code vulnerabilities                             |
| **SCA**       | Trivy, OSV-Scanner, Grype                                  | Software composition analysis for dependency vulnerabilities                |
| **Secrets**   | Gitleaks, TruffleHog, detect-secrets                       | Detect leaked API keys, tokens, passwords                                   |
| **Container** | Hadolint, Dockle, Trivy image scan, Trivy config           | Dockerfile linting, image scanning, config analysis                         |
| **IaC**       | Checkov, TFLint, KICS, Trivy config                        | Terraform, CloudFormation, Kubernetes, Helm, Ansible scanning               |
| **DAST**      | OWASP ZAP, Nuclei, httpx, gospider                         | Dynamic testing against running applications                                |
| **Recon**     | subfinder, naabu, httpx, nuclei                            | Subdomain enumeration, port scanning, HTTP probing, vulnerability templates |

### Code Quality

- **Metrics**: Lines of code, file size analysis, large file detection
- **Documentation checks**: README, LICENSE, CONTRIBUTING presence
- **CI/CD checks**: GitHub Actions workflow detection
- **Complexity analysis**: File-level complexity metrics
- **Health Score**: Automated 0-100 scoring based on findings

### Linting (34+ Languages)

| Language   | Linter(s)                  | Languages      | Linter(s)                |
| ---------- | -------------------------- | -------------- | ------------------------ |
| JavaScript | ESLint, Biome              | TypeScript     | tsc, ESLint              |
| Python     | Ruff, Flake8, Black        | Rust           | Clippy, rustfmt          |
| Go         | go vet, staticcheck, gofmt | Java           | Checkstyle, PMD          |
| Kotlin     | ktlint                     | Scala          | Scalafmt                 |
| C#         | dotnet format, Roslyn      | C/C++          | clang-tidy, cppcheck     |
| Ruby       | RuboCop, Brakeman          | PHP            | PHP_CodeSniffer, PHPStan |
| Swift      | SwiftLint, SwiftFormat     | Haskell        | HLint                    |
| Elixir     | Credo, Mix format          | Dart           | dart analyze             |
| Shell      | ShellCheck                 | Lua            | luacheck                 |
| Perl       | PerlCritic                 | R              | lintr                    |
| Julia      | JuliaFormatter             | PowerShell     | PSScriptAnalyzer         |
| SQL        | sqlfluff                   | GraphQL        | ESLint plugin            |
| Protobuf   | buf lint                   | CSS            | Stylelint                |
| HTML       | HTMLHint                   | YAML           | yamllint                 |
| JSON       | jsonlint                   | Markdown       | markdownlint             |
| Terraform  | tflint, terraform fmt      | CloudFormation | cfn-lint                 |
| Kubernetes | kubeval, kubeconform       | Helm           | helm lint                |
| Docker     | Hadolint                   | Ansible        | ansible-lint             |

### Dependency Management (21+ Ecosystems)

| Ecosystem      | Audit Tool               | Ecosystem      | Audit Tool          |
| -------------- | ------------------------ | -------------- | ------------------- |
| npm/yarn/pnpm  | npm audit                | pip/poetry/pdm | pip-audit           |
| Cargo (Rust)   | cargo-audit              | Go modules     | govulncheck         |
| Maven          | OWASP dep-check          | Gradle         | OWASP dep-check     |
| Bundler (Ruby) | bundler-audit            | Composer (PHP) | composer audit      |
| NuGet (.NET)   | dotnet list --vulnerable | Swift          | swift package audit |
| Pub (Dart)     | dart pub audit           | Hex (Elixir)   | mix deps.audit      |
| Conan (C/C++)  | conan inspect            | vcpkg (C/C++)  | vcpkg audit         |
| Zig            | build.zig check          | Nim            | nimble audit        |
| Crystal        | shards check             | R              | renv::dependencies  |
| Julia          | Pkg.status()             | Terraform      | lock file check     |
| Docker         | base image check         |                |                     |

### License Compliance

- **FOSSA CLI** integration for enterprise-grade scanning
- **ScanCode Toolkit** for deep license detection
- **Per-ecosystem** license checking (npm, pip, Cargo, Go, Composer)
- Configurable allowed/denied license lists

### SBOM Generation

- **CycloneDX** format output
- **SPDX** format output
- Powered by **Syft** from Anchore
- Supports filesystem and Docker image scanning

### Additional Features

- **SARIF Integration**: Automatic upload to GitHub Security tab
- **Auto-fix**: Automatically fix linting issues when possible
- **Severity Thresholds**: Fail on critical, high, medium, low, or never
- **Health Score**: Automated project health scoring (0-100)
- **Outdated Checker**: Detect outdated dependencies across all ecosystems
- **Auto-detection**: Automatically detect languages and project types
- **Monorepo Support**: Scan multiple directories and languages simultaneously

---

## Quick Start

```yaml
# .github/workflows/ci.yml
name: CI
on: [push, pull_request]

jobs:
  idevops:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - uses: TAI-opensource/idevops/actions/idevops@main
        with:
          languages: "javascript,typescript"
```

That is it. **One step. One config. All tools.**

---

## Supported Languages (34+)

iDevOps automatically detects and supports linting, security scanning, and dependency auditing for:

| Category                | Languages                                                    |
| ----------------------- | ------------------------------------------------------------ |
| **Web**                 | JavaScript, TypeScript, CSS, HTML, GraphQL                   |
| **Systems**             | C, C++, Rust, Go                                             |
| **Enterprise**          | Java, Kotlin, Scala, C#, F#                                  |
| **Scripting**           | Python, Ruby, PHP, Perl, Lua, Shell                          |
| **Mobile**              | Swift, Dart                                                  |
| **Functional**          | Haskell, Elixir, Scala                                       |
| **Data**                | R, Julia, SQL, PowerShell                                    |
| **Config/Data Formats** | YAML, JSON, Protobuf, Markdown                               |
| **Infrastructure**      | Terraform, CloudFormation, Kubernetes, Helm, Docker, Ansible |

---

## Inputs

| Input          | Description                                                                                                                                                                                                                                                                            | Default                 |
| -------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------- |
| `token`        | GitHub token for API access                                                                                                                                                                                                                                                            | `${{ github.token }}`   |
| `languages`    | Comma-separated languages to scan: `javascript,typescript,python,rust,go,java,kotlin,csharp,c,cpp,ruby,php,swift,scala,haskell,elixir,dart,shell,lua,perl,r,julia,powershell,sql,graphql,protobuf,css,html,yaml,json,markdown,terraform,cloudformation,kubernetes,helm,docker,ansible` | `javascript,typescript` |
| `security`     | Run security scans (Trivy, OSV-Scanner, Semgrep)                                                                                                                                                                                                                                       | `true`                  |
| `codeql`       | Run CodeQL analysis                                                                                                                                                                                                                                                                    | `true`                  |
| `secrets`      | Scan for leaked secrets (Gitleaks, TruffleHog)                                                                                                                                                                                                                                         | `true`                  |
| `lint`         | Run language linters (ESLint, Ruff, Clippy, Hadolint)                                                                                                                                                                                                                                  | `true`                  |
| `quality`      | Run code quality checks (complexity, duplication, metrics)                                                                                                                                                                                                                             | `true`                  |
| `dependencies` | Check for outdated/vulnerable dependencies                                                                                                                                                                                                                                             | `true`                  |
| `docker`       | Lint Dockerfiles with Hadolint                                                                                                                                                                                                                                                         | `false`                 |
| `fail-on`      | Fail workflow on severity: `critical`, `high`, `medium`, `low`, `never`                                                                                                                                                                                                                | `high`                  |
| `fix`          | Auto-fix issues when possible                                                                                                                                                                                                                                                          | `false`                 |
| `upload-sarif` | Upload SARIF results to GitHub Security tab                                                                                                                                                                                                                                            | `true`                  |
| `cache`        | Cache tool installations                                                                                                                                                                                                                                                               | `true`                  |

---

## Outputs

| Output        | Description                                              |
| ------------- | -------------------------------------------------------- |
| `summary`     | Markdown summary of all checks with findings breakdown   |
| `score`       | Overall project health score (0-100)                     |
| `sarif-files` | Comma-separated list of generated SARIF files for upload |

---

## Usage Examples

### Minimal (Auto-detect Everything)

```yaml
- uses: TAI-opensource/idevops/actions/idevops@main
  with:
    languages: "auto"
```

### Language-Specific: JavaScript/TypeScript

```yaml
- uses: TAI-opensource/idevops/actions/idevops@main
  with:
    languages: "javascript,typescript"
    security: "true"
    secrets: "true"
    lint: "true"
    quality: "true"
    dependencies: "true"
```

### Language-Specific: Python

```yaml
- uses: TAI-opensource/idevops/actions/idevops@main
  with:
    languages: "python"
    security: "true"
    lint: "true"
    dependencies: "true"
```

### Language-Specific: Rust

```yaml
- uses: TAI-opensource/idevops/actions/idevops@main
  with:
    languages: "rust"
    security: "true"
    lint: "true"
    dependencies: "true"
```

### Language-Specific: Go

```yaml
- uses: TAI-opensource/idevops/actions/idevops@main
  with:
    languages: "go"
    security: "true"
    lint: "true"
    dependencies: "true"
```

### Security-Focused Scan

```yaml
- uses: TAI-opensource/idevops/actions/idevops@main
  with:
    security: "true"
    codeql: "true"
    secrets: "true"
    lint: "false"
    quality: "false"
    dependencies: "false"
```

### Full Pipeline (Everything Enabled)

```yaml
- uses: TAI-opensource/idevops/actions/idevops@main
  with:
    languages: "javascript,typescript,python,rust,go,java,docker"
    security: "true"
    codeql: "true"
    secrets: "true"
    lint: "true"
    quality: "true"
    dependencies: "true"
    docker: "true"
    fail-on: "high"
    upload-sarif: "true"
```

### Monorepo Support

```yaml
strategy:
  matrix:
    include:
      - dir: frontend
        languages: "javascript,typescript"
      - dir: backend
        languages: "python,go"
      - dir: infra
        languages: "terraform,ansible,docker"

steps:
  - uses: actions/checkout@v4

  - uses: TAI-opensource/idevops/actions/idevops@main
    with:
      languages: "${{ matrix.languages }}"
      security: "true"
      secrets: "true"
      lint: "true"
```

### Docker / Kubernetes Projects

```yaml
- uses: TAI-opensource/idevops/actions/idevops@main
  with:
    languages: "docker,kubernetes,helm"
    security: "true"
    lint: "true"
    docker: "true"
```

### Terraform / IaC Projects

```yaml
- uses: TAI-opensource/idevops/actions/idevops@main
  with:
    languages: "terraform,cloudformation,ansible"
    security: "true"
    lint: "true"
```

### Strict Mode (Fail on Critical Only)

```yaml
- uses: TAI-opensource/idevops/actions/idevops@main
  with:
    languages: "javascript,typescript,python"
    fail-on: "critical"
```

### Informational Mode (Never Fail)

```yaml
- uses: TAI-opensource/idevops/actions/idevops@main
  with:
    languages: "javascript,typescript"
    fail-on: "never"
```

### With Auto-fix

```yaml
- uses: TAI-opensource/idevops/actions/idevops@main
  with:
    languages: "javascript,typescript"
    fix: "true"
    lint: "true"
```

### With Semgrep App Token (Custom Rules)

```yaml
- uses: TAI-opensource/idevops/actions/idevops@main
  with:
    security: "true"
  env:
    SEMGREP_APP_TOKEN: ${{ secrets.SEMGREP_APP_TOKEN }}
```

### SARIF Upload to Security Tab

```yaml
- uses: TAI-opensource/idevops/actions/idevops@main
  id: idevops
  with:
    upload-sarif: "true"

- uses: github/codeql-action/upload-sarif@v3
  if: always()
  with:
    sarif_files: ${{ steps.idevops.outputs.sarif-files }}
```

---

## Architecture

iDevOps is a composite GitHub Action that orchestrates 50+ scripts in a structured pipeline:

```
iDevOps Pipeline
├── 1. Validation & Setup
│   ├── Input validation
│   └── Tool installation (chmod +x scripts)
│
├── 2. Security Scans
│   ├── Trivy filesystem scan (vulnerabilities + misconfigs)
│   ├── OSV-Scanner (dependency vulnerabilities)
│   ├── Semgrep SAST (static analysis)
│   └── CodeQL (deep semantic analysis)
│
├── 3. Secret Detection
│   ├── Gitleaks (pattern-based scanning)
│   └── TruffleHog (entropy + verified scanning)
│
├── 4. Linting
│   ├── Language-specific linters (ESLint, Ruff, Clippy, etc.)
│   ├── Docker linting (Hadolint)
│   └── Auto-fix capability
│
├── 5. Dependency Checks
│   ├── Vulnerability audit (npm audit, pip-audit, cargo-audit, etc.)
│   ├── Outdated dependency detection
│   └── License compliance checking
│
├── 6. Code Quality
│   ├── Project statistics
│   ├── Complexity metrics
│   ├── Documentation checks
│   └── Health score calculation
│
└── 7. Reporting
    ├── SARIF file generation
    ├── Summary report
    └── GitHub Actions outputs
```

### Script Categories

| Category     | Scripts                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                    | Purpose                         |
| ------------ | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------- |
| Security     | `security-trivy.sh`, `security-osv.sh`, `security-semgrep.sh`, `security-universal.sh`                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                     | Vulnerability and SAST scanning |
| Secrets      | `secrets-gitleaks.sh`, `secrets-trufflehog.sh`                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                             | Secret detection                |
| Container    | `container-scanner.sh`, `container-dockerfile.sh`, `container-image.sh`                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                    | Container security              |
| IaC          | `iac-scanner.sh`, `iac-terraform.sh`, `iac-cloudformation.sh`, `iac-kubernetes.sh`, `iac-ansible.sh`                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                       | Infrastructure as Code          |
| DAST         | `dast-scanner.sh`                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                          | Dynamic application testing     |
| Recon        | `recon-scanner.sh`                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                         | Security reconnaissance         |
| Linting      | `lint-js.sh`, `lint-python.sh`, `lint-rust.sh`, `lint-go.sh`, `lint-java.sh`, `lint-kotlin.sh`, `lint-csharp.sh`, `lint-c-cpp.sh`, `lint-ruby.sh`, `lint-php.sh`, `lint-swift.sh`, `lint-scala.sh`, `lint-haskell.sh`, `lint-elixir.sh`, `lint-dart.sh`, `lint-shell.sh`, `lint-lua.sh`, `lint-perl.sh`, `lint-r.sh`, `lint-julia.sh`, `lint-powershell.sh`, `lint-sql.sh`, `lint-graphql.sh`, `lint-protobuf.sh`, `lint-css.sh`, `lint-html.sh`, `lint-yaml.sh`, `lint-json.sh`, `lint-markdown.sh`, `lint-docker.sh`, `lint-terraform.sh`, `lint-kubernetes.sh`, `lint-helm.sh`, `lint-ansible.sh`, `lint-javascript.sh` | Language-specific linting       |
| Dependencies | `deps-universal.sh`, `deps-audit.sh`, `deps-npm.sh`, `deps-pip.sh`, `deps-cargo.sh`, `deps-go.sh`, `deps-maven.sh`, `deps-gradle.sh`, `deps-bundler.sh`, `deps-composer.sh`, `deps-nuget.sh`                                                                                                                                                                                                                                                                                                                                                                                                                               | Dependency auditing             |
| SBOM         | `sbom-generator.sh`                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                        | Software Bill of Materials      |
| License      | `license-scanner.sh`                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                       | License compliance              |
| Quality      | `quality.sh`                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                               | Code quality metrics            |
| Outdated     | `outdated-checker.sh`                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                      | Outdated dependency detection   |
| Reporting    | `summary.sh`                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                               | Final report generation         |

---

## Script Reference

| Script                    | Description                                                                          |
| ------------------------- | ------------------------------------------------------------------------------------ |
| `security-trivy.sh`       | Trivy filesystem vulnerability scan                                                  |
| `security-osv.sh`         | OSV-Scanner dependency vulnerability check                                           |
| `security-semgrep.sh`     | Semgrep SAST static analysis                                                         |
| `security-universal.sh`   | Universal security scanner (SAST, SCA, secrets, container, IaC)                      |
| `secrets-gitleaks.sh`     | Gitleaks secret detection                                                            |
| `secrets-trufflehog.sh`   | TruffleHog deep secret scanning                                                      |
| `container-scanner.sh`    | Container security scanner (Hadolint + Dockle + Trivy + Grype + Syft)                |
| `container-dockerfile.sh` | Dockerfile security checks                                                           |
| `container-image.sh`      | Container image vulnerability scanning                                               |
| `iac-scanner.sh`          | Universal IaC scanner (Terraform, CloudFormation, K8s, Helm, Ansible, Pulumi, Bicep) |
| `iac-terraform.sh`        | Terraform-specific scanning                                                          |
| `iac-cloudformation.sh`   | AWS CloudFormation scanning                                                          |
| `iac-kubernetes.sh`       | Kubernetes/Helm manifest scanning                                                    |
| `iac-ansible.sh`          | Ansible playbook scanning                                                            |
| `dast-scanner.sh`         | DAST scanner (OWASP ZAP + Nuclei + httpx + gospider)                                 |
| `recon-scanner.sh`        | Security reconnaissance (subfinder + naabu + httpx + nuclei)                         |
| `lint-js.sh`              | JavaScript linting (ESLint/Biome)                                                    |
| `lint-javascript.sh`      | JavaScript linting (extended)                                                        |
| `lint-python.sh`          | Python linting (Ruff/Flake8/Black)                                                   |
| `lint-rust.sh`            | Rust linting (Clippy/rustfmt)                                                        |
| `lint-go.sh`              | Go linting (go vet/staticcheck/gofmt)                                                |
| `lint-java.sh`            | Java linting (Checkstyle/PMD)                                                        |
| `lint-kotlin.sh`          | Kotlin linting (ktlint)                                                              |
| `lint-csharp.sh`          | C# linting (dotnet format/Roslyn)                                                    |
| `lint-c-cpp.sh`           | C/C++ linting (clang-tidy/cppcheck)                                                  |
| `lint-ruby.sh`            | Ruby linting (RuboCop)                                                               |
| `lint-php.sh`             | PHP linting (PHP_CodeSniffer/PHPStan)                                                |
| `lint-swift.sh`           | Swift linting (SwiftLint/SwiftFormat)                                                |
| `lint-scala.sh`           | Scala linting (Scalafmt)                                                             |
| `lint-haskell.sh`         | Haskell linting (HLint)                                                              |
| `lint-elixir.sh`          | Elixir linting (Credo/Mix format)                                                    |
| `lint-dart.sh`            | Dart linting (dart analyze)                                                          |
| `lint-shell.sh`           | Shell script linting (ShellCheck)                                                    |
| `lint-lua.sh`             | Lua linting (luacheck)                                                               |
| `lint-perl.sh`            | Perl linting (PerlCritic)                                                            |
| `lint-r.sh`               | R linting (lintr)                                                                    |
| `lint-julia.sh`           | Julia linting (JuliaFormatter)                                                       |
| `lint-powershell.sh`      | PowerShell linting (PSScriptAnalyzer)                                                |
| `lint-sql.sh`             | SQL linting (sqlfluff)                                                               |
| `lint-graphql.sh`         | GraphQL linting (ESLint plugin)                                                      |
| `lint-protobuf.sh`        | Protobuf linting (buf)                                                               |
| `lint-css.sh`             | CSS linting (Stylelint)                                                              |
| `lint-html.sh`            | HTML linting (HTMLHint)                                                              |
| `lint-yaml.sh`            | YAML linting (yamllint)                                                              |
| `lint-json.sh`            | JSON linting (jsonlint)                                                              |
| `lint-markdown.sh`        | Markdown linting (markdownlint)                                                      |
| `lint-docker.sh`          | Dockerfile linting (Hadolint)                                                        |
| `lint-terraform.sh`       | Terraform linting (tflint/terraform fmt)                                             |
| `lint-kubernetes.sh`      | Kubernetes manifest linting (kubeval/kubeconform)                                    |
| `lint-helm.sh`            | Helm chart linting (helm lint)                                                       |
| `lint-ansible.sh`         | Ansible linting (ansible-lint)                                                       |
| `deps-universal.sh`       | Universal dependency auditor (21+ ecosystems)                                        |
| `deps-audit.sh`           | Dependency vulnerability audit                                                       |
| `deps-npm.sh`             | npm/yarn/pnpm dependency audit                                                       |
| `deps-pip.sh`             | pip/poetry/pdm dependency audit                                                      |
| `deps-cargo.sh`           | Cargo (Rust) dependency audit                                                        |
| `deps-go.sh`              | Go module dependency audit                                                           |
| `deps-maven.sh`           | Maven dependency audit                                                               |
| `deps-gradle.sh`          | Gradle dependency audit                                                              |
| `deps-bundler.sh`         | Bundler (Ruby) dependency audit                                                      |
| `deps-composer.sh`        | Composer (PHP) dependency audit                                                      |
| `deps-nuget.sh`           | NuGet (.NET) dependency audit                                                        |
| `sbom-generator.sh`       | SBOM generation (CycloneDX + SPDX via Syft)                                          |
| `license-scanner.sh`      | License compliance scanning                                                          |
| `outdated-checker.sh`     | Outdated dependency detection                                                        |
| `quality.sh`              | Code quality metrics and analysis                                                    |
| `summary.sh`              | Final report and health score generation                                             |

---

## Example Output

```
==========================================================
  [iDevOps] Final Report
==========================================================

  trivy-results: 2 findings (C:0 H:1 M:1)
  eslint-results: 5 findings (C:0 H:0 M:5)
  gitleaks-results: 0 findings (C:0 H:0 M:0)

==========================================================
  [iDevOps] Summary
==========================================================

  Total findings: 7
  Critical:       0
  High:           1
  Medium:         6
  Low:            0

  Health Score: 87/100
==========================================================
```

---

## License

MIT -- use it anywhere, no restrictions.

---

## Contributing

Contributions welcome! See [CONTRIBUTING.md](CONTRIBUTING.md).

To add a new linter or scanner:

1. Create a new script in `scripts/` following the existing naming convention
2. Add it to the appropriate step in `action.yml`
3. Update this README with the new tool documentation
4. Test with the CI workflow

---

## Support

- **Issues**: [GitHub Issues](https://github.com/TAI-opensource/idevops/issues)
- **Discussions**: [GitHub Discussions](https://github.com/TAI-opensource/idevops/discussions)
- **Pull Requests**: [Pull Requests](https://github.com/TAI-opensource/idevops/pulls)

---

## Credits

Built on top of these amazing open-source tools:

- [Trivy](https://github.com/aquasecurity/trivy) -- Aqua Security
- [OSV-Scanner](https://github.com/google/osv-scanner) -- Google
- [Semgrep](https://github.com/semgrep/semgrep) -- Semgrep Inc.
- [CodeQL](https://github.com/github/codeql) -- GitHub
- [Gitleaks](https://github.com/gitleaks/gitleaks) -- Gitleaks
- [TruffleHog](https://github.com/trufflesecurity/trufflehog) -- Truffle Security
- [Ruff](https://github.com/astral-sh/ruff) -- Astral
- [Clippy](https://github.com/rust-lang/rust-clippy) -- Rust Lang
- [Hadolint](https://github.com/hadolint/hadolint) -- Hadolint
- [Bandit](https://github.com/PyCQA/bandit) -- PyCQA
- [Brakeman](https://github.com/presidentbeef/brakeman) -- Presidentbeef
- [Gosec](https://github.com/securego/gosec) -- SecureGo
- [Checkov](https://github.com/bridgecrewio/checkov) -- Bridgecrew
- [Grype](https://github.com/anchore/grype) -- Anchore
- [Syft](https://github.com/anchore/syft) -- Anchore
- [OWASP ZAP](https://github.com/zaproxy/zaproxy) -- OWASP
- [Nuclei](https://github.com/projectdiscovery/nuclei) -- ProjectDiscovery
- [Detect-secrets](https://github.com/Yelp/detect-secrets) -- Yelp
- [FindSecBugs](https://github.com/find-sec-bugs/find-sec-bugs) -- FindSecBugs
- [PMD](https://github.com/pmd/pmd) -- PMD
- [KICS](https://github.com/Checkmarx/kics) -- Checkmarx
- [TFLint](https://github.com/terraform-linters/tflint) -- TFLint
- [Dockle](https://github.com/goodwithtech/dockle) -- Goodwithtech
- [ScanCode Toolkit](https://github.com/nexB/scancode-toolkit) -- aboutCode
