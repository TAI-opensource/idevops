# iDevOps

> One GitHub Action to rule them all.

[![GitHub Marketplace](https://img.shields.io/badge/Marketplace-iDevOps-blue?logo=github)](https://github.com/marketplace/actions/idevops)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![GitHub Stars](https://img.shields.io/github/stars/TAI-opensource/idevops?style=social)](https://github.com/TAI-opensource/idevops)

**iDevOps** is a free, open-source GitHub Action that replaces 12+ separate security, linting, and quality tools with a single, unified pipeline. One step. One config. Every check.

No vendor lock-in. No per-seat pricing. No black boxes. Just one action that does everything.

## Why iDevOps?

Most teams use 5-10 different tools across their CI pipelines -- each with its own config file, its own learning curve, its own billing model. iDevOps bundles them into one reusable action that works everywhere: open-source libraries, internal APIs, enterprise monorepos, side projects -- it doesn't matter.

| Problem                                   | iDevOps Solution                           |
| ----------------------------------------- | ------------------------------------------ |
| "We have 8 different CI tools"            | 1 action replaces them all                 |
| "Setting up security scanning takes days" | 1 line of config                           |
| "Our tools conflict with each other"      | Tested together, guaranteed compatible     |
| "We can't afford Snyk/SonarQube"          | 100% free, MIT licensed                    |
| "Our private repo needs security checks"  | Works on public AND private repos          |
| "We have a monorepo with 5 languages"     | Detects and lints everything automatically |

## What's Inside

| Layer                      | Tools                                          | What It Catches                               |
| -------------------------- | ---------------------------------------------- | --------------------------------------------- |
| **Vulnerability Scanning** | Trivy, OSV-Scanner                             | CVEs in dependencies, containers, IaC         |
| **Static Analysis (SAST)** | Semgrep, CodeQL                                | Injection, XSS, auth flaws, logic bugs        |
| **Secret Detection**       | Gitleaks, TruffleHog                           | API keys, tokens, passwords in git history    |
| **Dependency Audit**       | npm audit, pip-audit, cargo-audit, govulncheck | Known vulnerabilities in packages             |
| **Linting**                | ESLint, Biome, Ruff, Clippy, Hadolint, go vet  | Code style, bugs, anti-patterns               |
| **Code Quality**           | Built-in metrics                               | Complexity, file size, documentation coverage |
| **Docker**                 | Hadolint                                       | Dockerfile best practices and security        |

## Quick Start

Add one step to your workflow. That's it.

```yaml
- uses: TAI-opensource/idevops/actions/idevops@main
  with:
    languages: "javascript,typescript"
```

The action auto-detects what's installed and runs only the relevant checks. No configuration files to maintain, no plugins to install locally.

## Works Everywhere

| Project Type           | Example                               | Supported |
| ---------------------- | ------------------------------------- | --------- |
| Open-source library    | `react`, `express`, `fastapi`         | Yes       |
| Private enterprise app | Internal dashboards, APIs             | Yes       |
| Monorepo               | Turborepo, Nx, Lerna                  | Yes       |
| Small side project     | Weekend hacks, prototypes             | Yes       |
| Multi-language repo    | JS frontend + Python backend + Go API | Yes       |
| Dockerized app         | Any Dockerfile                        | Yes       |
| Rust/Go systems        | CLI tools, infrastructure             | Yes       |

One action. Every project. Every scale.

## Usage Examples

### Minimal (just works)

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
    codeql: "true"
    secrets: "true"
    lint: "true"
    quality: "true"
    dependencies: "true"
    docker: "true"
```

### Security Only (for regulated environments)

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

### Strict Mode (zero tolerance)

```yaml
- uses: TAI-opensource/idevops/actions/idevops@main
  with:
    fail-on: "critical"
```

## Inputs

| Input          | Description                                   | Default                 |
| -------------- | --------------------------------------------- | ----------------------- |
| `languages`    | `javascript,typescript,python,rust,go,docker` | `javascript,typescript` |
| `security`     | Trivy + OSV-Scanner + Semgrep                 | `true`                  |
| `codeql`       | CodeQL semantic analysis                      | `true`                  |
| `secrets`      | Gitleaks + TruffleHog                         | `true`                  |
| `lint`         | Language-specific linters                     | `true`                  |
| `quality`      | Metrics and complexity checks                 | `true`                  |
| `dependencies` | Vulnerability & outdated checks               | `true`                  |
| `docker`       | Hadolint Dockerfile linting                   | `false`                 |
| `fail-on`      | `critical`, `high`, `medium`, `low`, `never`  | `high`                  |
| `fix`          | Auto-fix when possible                        | `false`                 |
| `upload-sarif` | Push results to Security tab                  | `true`                  |

## Outputs

| Output        | Description                         |
| ------------- | ----------------------------------- |
| `summary`     | Markdown report of all findings     |
| `score`       | Project health score (0-100)        |
| `sarif-files` | SARIF files for GitHub Security tab |

## Report Format

Every run produces a unified report:

```
==========================================================
  [iDevOps] Final Report
==========================================================

  trivy-results: 0 findings (C:0 H:0 M:0)
  eslint-results: 3 findings (C:0 H:0 M:3)
  gitleaks-results: 0 findings (C:0 H:0 M:0)

==========================================================
  [iDevOps] Summary
==========================================================

  Total findings: 3
  Critical:       0
  High:           0
  Medium:         3

  Health Score: 97/100
==========================================================
```

Results are also uploaded as SARIF to the GitHub Security tab when `upload-sarif` is enabled.

## Compared to Alternatives

| Feature       | iDevOps          | Renovate + Trivy + Semgrep + ESLint + ... | Snyk              |
| ------------- | ---------------- | ----------------------------------------- | ----------------- |
| Setup time    | 1 line           | 5-10 config files                         | Account + config  |
| Cost          | Free forever     | Free (but complex)                        | Paid per seat     |
| Languages     | 6+ in one action | Separate configs each                     | Limited free tier |
| Private repos | Yes              | Yes                                       | Paywall           |
| Maintenance   | Zero             | High (tool updates)                       | Vendor-dependent  |
| SARIF output  | Built-in         | Manual per tool                           | Yes               |
| Open source   | Yes (MIT)        | Partially                                 | No                |

## License

MIT. Use it anywhere. No restrictions. No attribution required.

## Contributing

Contributions, issues, and feature requests are welcome.

## Built On

iDevOps stands on the shoulders of these incredible open-source projects:

[Trivy](https://github.com/aquasecurity/trivy) | [OSV-Scanner](https://github.com/google/osv-scanner) | [Semgrep](https://github.com/semgrep/semgrep) | [CodeQL](https://github.com/github/codeql) | [Gitleaks](https://github.com/gitleaks/gitleaks) | [TruffleHog](https://github.com/trufflesecurity/trufflehog) | [Ruff](https://github.com/astral-sh/ruff) | [Hadolint](https://github.com/hadolint/hadolint) | [Clippy](https://github.com/rust-lang/rust-clippy)
