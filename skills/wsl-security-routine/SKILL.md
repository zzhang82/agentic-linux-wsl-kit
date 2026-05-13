---
name: wsl-security-routine
description: run recurring read-only WSL/Linux security posture checks, summarize evidence, recommend safe fixes, and escalate to package-security-update only after approval.
version: 1.0.0
---

# Skill: wsl-security-routine

Run recurring read-only WSL/Linux security posture checks, summarize evidence, recommend safe fixes, and escalate to package-security-update only after approval.

## Usage

Trigger this skill when you need to audit the security posture of the WSL environment or a specific project repository.

### Modes

- `--daily`: Fast, local, no sudo, no network. Checks OS baseline, package health (local), and secret directory metadata.
- `--weekly`: Network allowed. Includes Lynis audit, Gitleaks repo scans, and Trivy filesystem scans.
- `--monthly`: Deep scan. Includes SBOM generation (Syft), vulnerability scan (Grype), and TruffleHog verification.
- `--preflight`: Fast check before coding-agent work. Runs `linux-doctor`, `git status`, and `gitleaks` on the active repo.

## Safety Guardrails

- **Read-Only**: The routine only produces evidence and reports. It does not auto-fix or modify the system.
- **No Secrets**: Reports must never contain raw tokens, private keys, or credentials. Use `--redact` where available.
- **Human-Approved Fixes**: Any recommended action (like `apt upgrade`) must be explicitly approved by a human before execution.
- **No Sudo by Default**: Daily and preflight modes should run without elevated privileges.

## Tools Integrated

- `linux-doctor.sh`: OS/WSL baseline.
- `package-security-check.sh`: Package/repo security.
- `lynis`: System hardening audit.
- `gitleaks`: Secret detection in repositories.
- `trivy`: Filesystem/container vulnerability scan.
- `syft` + `grype`: SBOM-first vulnerability scanning.

## Workflow

1. Identify the scope (distro, project path) and mode.
2. Run `scripts/wsl-security-check.sh --<mode>`.
3. Review the summary generated in `~/.local/state/wsl-security/`.
4. If risks are found, propose a safe, manual fix plan.
5. Escalation: Use `package-security-update` skill only for approved package fixes.
