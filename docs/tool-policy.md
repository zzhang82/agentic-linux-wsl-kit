# Aegis Skills security tool policy

This document defines the selection and usage policy for security tools included in or recommended by Aegis Skills.

Aegis Skills is not a background security agent. It is a skill-and-script automation layer that runs checks on demand or through user-configured schedules.

## Selection criteria

Tools integrated into Aegis Skills should meet the following criteria:

1. **Open source**: Prefer GPL, MIT, or Apache-licensed tools.
2. **Read-only by default**: Tools must support a non-destructive audit mode.
3. **Agent-friendly output**: Output should be parseable as JSON, NDJSON, or clean structured text.
4. **Minimal footprint**: Avoid heavy background agents unless explicitly needed.
5. **Redaction support**: Secret scanners must support redaction or summary-only reporting.

## Core tools

### Lynis

- Purpose: system hardening audit and compliance testing.
- Usage: weekly/monthly.
- Risk: low in audit mode. Needs `sudo` for full audit.

### Gitleaks

- Purpose: detect secrets in repositories and dependency trees.
- Usage: weekly/monthly/preflight/postinstall.
- Risk: low when `--redact` is used.

### Trivy

- Purpose: vulnerability and secret scanning for filesystems and containers.
- Usage: weekly/monthly/postinstall.
- Risk: medium when network updates are required.

### Syft and Grype

- Purpose: SBOM generation and vulnerability scanning.
- Usage: monthly.
- Risk: medium when network vulnerability data is required.

### TruffleHog

- Purpose: verified secret detection during deeper monthly checks.
- Usage: monthly.
- Risk: medium. Summaries should report counts, not raw secret material.

## Privileged operations

- Use `sudo -n` only where non-interactive sudo is explicitly expected.
- Never prompt for sudo inside unattended routines.
- Docker checks should run only when Docker is reachable and approved.
- Network operations are restricted to weekly/monthly modes by default.

## Data handling

- Do not print tokens, private keys, or credential contents.
- Prefer metadata, counts, and file paths over raw sensitive values.
- Store reports locally in `~/.local/state/wsl-security/`.
- Recommended retention: last 30 daily, 12 weekly, and 12 monthly reports.
