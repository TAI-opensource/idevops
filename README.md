# iDevOps

> One GitHub Action to rule them all.

[![GitHub Marketplace](https://img.shields.io/badge/Marketplace-iDevOps-blue?logo=github)](https://github.com/marketplace/actions/idevops)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![GitHub Stars](https://img.shields.io/github/stars/TAI-opensource/idevops?style=social)](https://github.com/TAI-opensource/idevops)

**iDevOps** is a free, open-source GitHub Action that replaces 30+ separate security, linting, dependency, and quality tools with a single, unified pipeline. One step. One config. Every check.

No vendor lock-in. No per-seat pricing. No black boxes. Just one action that does everything.

## Why iDevOps?

Most teams use 10-20 different tools across their CI pipelines -- each with its own config file, its own learning curve, its own billing model. iDevOps bundles them into one reusable action that works everywhere.

| Problem                                   | iDevOps Solution                           |
| ----------------------------------------- | ------------------------------------------ |
| "We have 15 different CI tools"           | 1 action replaces them all                 |
| "Setting up security scanning takes days" | 1 line of config                           |
| "Our tools conflict with each other"      | Tested together, guaranteed compatible     |
| "We can't afford Snyk/SonarQube"          | 100% free, MIT licensed                    |
| "Our private repo needs security checks"  | Works on public AND private repos          |
| "We have a monorepo with 5 languages"     | Detects and lints everything automatically |
| "We need IaC scanning too"                | Terraform, K8s, Docker, Ansible included   |

## What's Inside

| Layer                   | Tools                                                          | What It Catches                               |
| ----------------------- | -------------------------------------------------------------- | --------------------------------------------- |
| **SAST**                | Semgrep, Bandit, Brakeman, Gosec, FindSecBugs, PMD             | Injection, XSS, auth flaws, logic bugs        |
| **SCA**                 | Trivy, OSV-Scanner, Grype                                      | CVEs in dependencies, containers, IaC         |
| **Secret Detection**    | Gitleaks, TruffleHog, detect-secrets                           | API keys, tokens, passwords in git history    |
| **Dependency Audit**    | npm audit, pip-audit, cargo-audit, govulncheck, 21+ ecosystems | Known vulnerabilities in packages             |
| **Linting (34+ langs)** | ESLint, Ruff, Clippy, golangci-lint, Checkstyle, 30+ more      | Code style, bugs, anti-patterns               |
| **Container Security**  | Hadolint, Dockle, Trivy image scan, Grype                      | Dockerfile issues, image CVEs                 |
| **IaC Scanning**        | Checkov, TFLint, KICS, kubeconform, cfn-lint                   | Terraform, K8s, CloudFormation misconfigs     |
| **DAST**                | OWASP ZAP, Nuclei, httpx                                       | Dynamic testing against running apps          |
| **Recon**               | subfinder, naabu, httpx, nuclei                                | Subdomain enum, port scanning, vuln templates |
| **License Compliance**  | FOSSA, ScanCode, per-ecosystem tools                           | License violations and policy enforcement     |
| **SBOM**                | Syft (CycloneDX + SPDX)                                        | Software bill of materials                    |
| **Code Quality**        | Metrics, complexity, documentation checks                      | Code health scoring (0-100)                   |

## Quick Start

Add one step to your workflow. That's it.

```yaml
- uses: TAI-opensource/idevops/actions/idevops@main
  with:
    languages: "javascript,typescript"
```

The action auto-detects what's installed and runs only the relevant checks.

## Supported Languages (34+)

| Category       | Languages                                                    |
| -------------- | ------------------------------------------------------------ |
| **Web**        | JavaScript, TypeScript, CSS, HTML, GraphQL                   |
| **Systems**    | C, C++, Rust, Go                                             |
| **Enterprise** | Java, Kotlin, Scala, C#                                      |
| **Scripting**  | Python, Ruby, PHP, Perl, Lua, Shell                          |
| **Mobile**     | Swift, Dart                                                  |
| **Functional** | Haskell, Elixir                                              |
| **Data**       | R, Julia, SQL, PowerShell                                    |
| **Config**     | YAML, JSON, Protobuf, Markdown                               |
| **Infra**      | Terraform, CloudFormation, Kubernetes, Helm, Docker, Ansible |

## Usage Examples

### Minimal (auto-detect everything)

```yaml
name: CI
on: [push, pull_request]
jobs:
  check:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: TAI-opensource/idevops/actions/idevops@main
```

### Full Stack

```yaml
- uses: TAI-opensource/idevops/actions/idevops@main
  with:
    languages: "javascript,typescript,python,rust,go,docker"
    security: "true"
    secrets: "true"
    lint: "true"
    quality: "true"
    dependencies: "true"
    docker: "true"
```

### Security Only

```yaml
- uses: TAI-opensource/idevops/actions/idevops@main
  with:
    security: "true"
    secrets: "true"
    lint: "false"
    quality: "false"
    dependencies: "false"
```

### Python Library

```yaml
- uses: TAI-opensource/idevops/actions/idevops@main
  with:
    languages: "python"
    security: "true"
    lint: "true"
    dependencies: "true"
```

### Rust CLI Tool

```yaml
- uses: TAI-opensource/idevops/actions/idevops@main
  with:
    languages: "rust"
    security: "true"
    lint: "true"
    dependencies: "true"
```

### Docker/Kubernetes

```yaml
- uses: TAI-opensource/idevops/actions/idevops@main
  with:
    languages: "docker,kubernetes,helm"
    security: "true"
    lint: "true"
    docker: "true"
```

### Terraform/IaC

```yaml
- uses: TAI-opensource/idevops/actions/idevops@main
  with:
    languages: "terraform,cloudformation,ansible"
    security: "true"
    lint: "true"
```

### Monorepo

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
```

### Strict Mode

```yaml
- uses: TAI-opensource/idevops/actions/idevops@main
  with:
    fail-on: "critical"
```

## Inputs

| Input             | Description                       | Default                 |
| ----------------- | --------------------------------- | ----------------------- |
| `token`           | GitHub token                      | `${{ github.token }}`   |
| `languages`       | Comma-separated languages         | `javascript,typescript` |
| `security`        | Run security scans                | `true`                  |
| `sast`            | Run SAST scans                    | `true`                  |
| `sca`             | Run SCA scans                     | `true`                  |
| `secrets`         | Scan for secrets                  | `true`                  |
| `lint`            | Run linters                       | `true`                  |
| `lint-fix`        | Auto-fix issues                   | `false`                 |
| `quality`         | Code quality checks               | `true`                  |
| `dependencies`    | Dependency audit                  | `true`                  |
| `check-outdated`  | Check outdated deps               | `true`                  |
| `check-licenses`  | License compliance                | `false`                 |
| `docker`          | Lint Dockerfiles                  | `auto`                  |
| `container-image` | Scan container image              | empty                   |
| `iac`             | Scan IaC                          | `auto`                  |
| `iac-types`       | IaC types to scan                 | `auto`                  |
| `dast`            | DAST scanning                     | `false`                 |
| `target-url`      | URL for DAST                      | empty                   |
| `recon`           | Security recon                    | `false`                 |
| `sbom`            | Generate SBOM                     | `false`                 |
| `sbom-format`     | SBOM format (cyclonedx/spdx/both) | `both`                  |
| `fail-on`         | Fail threshold                    | `high`                  |
| `upload-sarif`    | Upload to Security tab            | `true`                  |
| `cache`           | Cache tools                       | `true`                  |
| `report-dir`      | Reports directory                 | `.idevops/reports`      |

## Outputs

| Output                  | Description                      |
| ----------------------- | -------------------------------- |
| `summary`               | Markdown summary of all findings |
| `score`                 | Health score (0-100)             |
| `sarif-files`           | SARIF files for upload           |
| `sbom-files`            | SBOM files generated             |
| `vulnerabilities-count` | Total vulnerabilities found      |
| `issues-count`          | Total linting issues             |
| `outdated-count`        | Outdated dependencies            |
| `licenses-issues`       | License compliance issues        |

## Scripts (67 total)

| Category      | Count | Scripts                                                                                                                                                                                                                                                                                                                                                                                                                            |
| ------------- | ----- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Security**  | 7     | security-universal, security-trivy, security-osv, security-semgrep, secrets-gitleaks, secrets-trufflehog, dast-scanner                                                                                                                                                                                                                                                                                                             |
| **Linting**   | 34    | lint-javascript, lint-python, lint-rust, lint-go, lint-java, lint-kotlin, lint-csharp, lint-c-cpp, lint-ruby, lint-php, lint-swift, lint-scala, lint-haskell, lint-elixir, lint-dart, lint-shell, lint-docker, lint-yaml, lint-markdown, lint-terraform, lint-sql, lint-graphql, lint-protobuf, lint-kubernetes, lint-helm, lint-ansible, lint-css, lint-html, lint-json, lint-lua, lint-perl, lint-r, lint-julia, lint-powershell |
| **Deps**      | 13    | deps-universal, deps-npm, deps-pip, deps-cargo, deps-go, deps-maven, deps-gradle, deps-bundler, deps-composer, deps-nuget, sbom-generator, license-scanner, outdated-checker                                                                                                                                                                                                                                                       |
| **IaC**       | 5     | iac-scanner, iac-terraform, iac-kubernetes, iac-cloudformation, iac-ansible                                                                                                                                                                                                                                                                                                                                                        |
| **Container** | 3     | container-scanner, container-dockerfile, container-image                                                                                                                                                                                                                                                                                                                                                                           |
| **Recon**     | 1     | recon-scanner                                                                                                                                                                                                                                                                                                                                                                                                                      |
| **Reports**   | 3     | summary, quality, sarif-upload                                                                                                                                                                                                                                                                                                                                                                                                     |

## Compared to Alternatives

| Feature       | iDevOps           | Renovate + Trivy + Semgrep + ESLint + ... | Snyk              |
| ------------- | ----------------- | ----------------------------------------- | ----------------- |
| Setup time    | 1 line            | 15-30 config files                        | Account + config  |
| Cost          | Free forever      | Free (but complex)                        | Paid per seat     |
| Languages     | 34+ in one action | Separate configs each                     | Limited free tier |
| Private repos | Yes               | Yes                                       | Paywall           |
| Maintenance   | Zero              | High (tool updates)                       | Vendor-dependent  |
| SARIF output  | Built-in          | Manual per tool                           | Yes               |
| Open source   | Yes (MIT)         | Partially                                 | No                |

## License

MIT. Use it anywhere. No restrictions.

## Contributing

Contributions, issues, and feature requests are welcome.

## Built On

iDevOps stands on the shoulders of these incredible open-source projects:

[Trivy](https://github.com/aquasecurity/trivy) | [OSV-Scanner](https://github.com/google/osv-scanner) | [Semgrep](https://github.com/semgrep/semgrep) | [Gitleaks](https://github.com/gitleaks/gitleaks) | [TruffleHog](https://github.com/trufflesecurity/trufflehog) | [Ruff](https://github.com/astral-sh/ruff) | [Clippy](https://github.com/rust-lang/rust-clippy) | [Hadolint](https://github.com/hadolint/hadolint) | [Bandit](https://github.com/PyCQA/bandit) | [Brakeman](https://github.com/presidentbeef/brakeman) | [Gosec](https://github.com/securego/gosec) | [Checkov](https://github.com/bridgecrewio/checkov) | [Grype](https://github.com/anchore/grype) | [Syft](https://github.com/anchore/syft) | [OWASP ZAP](https://github.com/zaproxy/zaproxy) | [Nuclei](https://github.com/projectdiscovery/nuclei) | [detect-secrets](https://github.com/Yelp/detect-secrets) | [golangci-lint](https://github.com/golangci/golangci-lint) | [ShellCheck](https://github.com/koalaman/shellcheck)
