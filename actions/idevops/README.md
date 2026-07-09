# 🛡️ iDevOps — All-in-One DevOps Pipeline

> **Free & Open-Source** GitHub Action that replaces 12+ separate tools with a single, unified pipeline.

[![GitHub Marketplace](https://img.shields.io/badge/Marketplace-iDevOps-blue?logo=github)](https://github.com/marketplace/actions/idevops)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

## 🔧 What's Included

| Category                | Tools Replaced                        | What It Does                    |
| ----------------------- | ------------------------------------- | ------------------------------- |
| 🛡️ **Security**         | Trivy, osv-scanner, Semgrep           | Vulnerability & SAST scanning   |
| 🔐 **Code Analysis**    | CodeQL                                | Deep semantic code analysis     |
| 🔑 **Secret Detection** | Gitleaks, TruffleHog                  | Find leaked secrets & API keys  |
| 🧹 **Linting**          | ESLint, Biome, Ruff, Clippy, Hadolint | Multi-language linting          |
| 📦 **Dependencies**     | Snyk, npm audit, pip-audit            | Vulnerability & outdated checks |
| 📊 **Quality**          | SonarQube Community                   | Metrics, complexity, docs check |
| 🐳 **Docker**           | Hadolint                              | Dockerfile best practices       |
| 🐍 **Python**           | Ruff, Flake8, Black                   | Lint + format in one tool       |
| 🦀 **Rust**             | Clippy, cargo-audit                   | Lint + security audit           |
| 🐹 **Go**               | go vet, staticcheck, govulncheck      | Lint + vulnerability check      |

## ⚡ Quick Start

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

That's it. **One step. One config. All tools.**

## 🎯 Usage Examples

### JavaScript/TypeScript Project

```yaml
- uses: TAI-opensource/idevops/actions/idevops@main
  with:
    languages: "javascript,typescript"
    security: "true"
    secrets: "true"
    lint: "true"
    quality: "true"
```

### Python Project

```yaml
- uses: TAI-opensource/idevops/actions/idevops@main
  with:
    languages: "python"
    security: "true"
    lint: "true"
    dependencies: "true"
```

### Full Stack (Multi-language)

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

### Security-Only Scan

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

### With Auto-fix

```yaml
- uses: TAI-opensource/idevops/actions/idevops@main
  with:
    languages: "javascript,typescript"
    fix: "true"
    lint: "true"
```

### Strict Mode (Fail on Any Issue)

```yaml
- uses: TAI-opensource/idevops/actions/idevops@main
  with:
    languages: "javascript,typescript"
    fail-on: "critical"
```

## 📥 Inputs

| Input          | Description                                                    | Default                 |
| -------------- | -------------------------------------------------------------- | ----------------------- |
| `languages`    | Comma-separated: `javascript,typescript,python,rust,go,docker` | `javascript,typescript` |
| `security`     | Run Trivy + osv-scanner + Semgrep                              | `true`                  |
| `codeql`       | Run CodeQL analysis                                            | `true`                  |
| `secrets`      | Run Gitleaks + TruffleHog                                      | `true`                  |
| `lint`         | Run language linters                                           | `true`                  |
| `quality`      | Run quality metrics                                            | `true`                  |
| `dependencies` | Check dependency vulnerabilities                               | `true`                  |
| `docker`       | Lint Dockerfiles with Hadolint                                 | `false`                 |
| `fail-on`      | Fail threshold: `critical`, `high`, `medium`, `low`, `never`   | `high`                  |
| `fix`          | Auto-fix issues when possible                                  | `false`                 |
| `upload-sarif` | Upload results to GitHub Security tab                          | `true`                  |

## 📤 Outputs

| Output        | Description                            |
| ------------- | -------------------------------------- |
| `summary`     | Markdown summary of all checks         |
| `score`       | Overall project health score (0-100)   |
| `sarif-files` | Comma-separated SARIF files for upload |

## 📊 Example Output

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  📋 iDevOps — Final Report
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  🔍 trivy-results: 2 findings (C:0 H:1 M:1)
  🔍 eslint-results: 5 findings (C:0 H:0 M:5)

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  📊 Summary
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  Total findings: 7
  Critical:       0
  High:           1
  Medium:         6
  Low:            0

  🏆 Health Score: 87/100
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

## 🔒 SARIF Integration

iDevOps uploads results to GitHub's Security tab via SARIF format:

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

## ⚙️ Advanced Configuration

### Custom Severity Thresholds

```yaml
# Only fail on critical issues
- uses: TAI-opensource/idevops/actions/idevops@main
  with:
    fail-on: "critical"

# Fail on anything above low
- uses: TAI-opensource/idevops/actions/idevops@main
  with:
    fail-on: "low"

# Never fail (informational only)
- uses: TAI-opensource/idevops/actions/idevops@main
  with:
    fail-on: "never"
```

### Selective Tools

```yaml
# Only security scanning
- uses: TAI-opensource/idevops/actions/idevops@main
  with:
    security: "true"
    codeql: "false"
    secrets: "false"
    lint: "false"
    quality: "false"
    dependencies: "false"
```

### With Semgrep App Token (for custom rules)

```yaml
- uses: TAI-opensource/idevops/actions/idevops@main
  with:
    security: "true"
  env:
    SEMGREP_APP_TOKEN: ${{ secrets.SEMGREP_APP_TOKEN }}
```

## 🤝 Contributing

Contributions welcome! See [CONTRIBUTING.md](CONTRIBUTING.md).

## 📄 License

MIT — use it anywhere, no restrictions.

## 🙏 Credits

Built on top of these amazing open-source tools:

- [Trivy](https://github.com/aquasecurity/trivy) — Aqua Security
- [OSV-Scanner](https://github.com/google/osv-scanner) — Google
- [Semgrep](https://github.com/semgrep/semgrep) — Semgrep Inc.
- [CodeQL](https://github.com/github/codeql) — GitHub
- [Gitleaks](https://github.com/gitleaks/gitleaks) — Gitleaks
- [TruffleHog](https://github.com/trufflesecurity/trufflehog) — Truffle Security
- [Ruff](https://github.com/astral-sh/ruff) — Astral
- [Hadolint](https://github.com/hadolint/hadolint) — Hadolint
- [Clippy](https://github.com/rust-lang/rust-clippy) — Rust Lang
