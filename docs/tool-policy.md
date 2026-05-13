# Security Tool Policy

This document defines the selection and usage policy for security tools included in or recommended by the Agentic Linux WSL Kit.

## Selection Criteria

Tools integrated into this kit must meet the following criteria:
1. **Open Source**: Prefer GPL, MIT, or Apache-licensed tools.
2. **Read-Only by Default**: Tools must support a non-destructive, audit-only mode.
3. **LLM-Friendly**: Output should be parseable (JSON, NDJSON, or clean structured text).
4. **Minimal Footprint**: Avoid heavy agents or continuous background processes where possible.

## Core Tools

### Lynis
- **Purpose**: System hardening audit and compliance testing.
- **Usage**: Weekly/Monthly.
- **Risk**: Low (Read-only). Needs `sudo` for full audit.

### Gitleaks
- **Purpose**: Detecting secrets in git repositories.
- **Usage**: Weekly/Monthly/Preflight.
- **Risk**: Low. Always use `--redact`.

### Trivy
- **Purpose**: Vulnerability scanner for filesystems and containers.
- **Usage**: Weekly/Monthly.
- **Risk**: Medium (Network required for vulnerability DB updates).

### Syft & Grype
- **Purpose**: SBOM generation and vulnerability scanning.
- **Usage**: Monthly.
- **Risk**: Medium (Network required).

## Privileged Operations

- **Sudo**: Only use `sudo` when necessary for a specific check (e.g., `lynis`, `apt-get update`).
- **Docker**: Docker checks are only performed if the Docker daemon is reachable and the user has approved the connection.
- **Network**: Network operations are restricted to `Weekly` and `Monthly` modes by default.

## Data Handling

- **Redaction**: Personal information, home paths (where possible), and secret contents must be redacted from reports.
- **Retention**: Security reports are stored locally in `~/.local/state/wsl-security/`. It is recommended to retain the last 30 daily, 12 weekly, and 12 monthly reports.
