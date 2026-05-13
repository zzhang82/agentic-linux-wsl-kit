# Aegis Skills security routine SOP

This document describes how to run recurring security checks with Aegis Skills.

Aegis Skills is not an agent. It provides reusable skills and scripts that humans or existing agents can run to inspect Linux/WSL environments safely.

## Overview

The security routine is read-only. It provides visibility into the system and project security posture without making automated changes.

It uses a tiered schedule to balance speed and depth.

| Frequency | Mode | Purpose |
| :--- | :--- | :--- |
| Daily | `--daily` | Baseline check for OS health and secret directory permissions. No network. |
| Weekly | `--weekly` | Network-enabled check including hardening and secret scanning. |
| Monthly | `--monthly` | Deep scan with SBOM and vulnerability scanning. |
| Pre-coding | `--preflight` | Fast check before an agent starts work in a repo. |

## Manual execution

Run from the repository root:

```bash
bash scripts/wsl-security-check.sh --daily
bash scripts/wsl-security-check.sh --weekly --project .
bash scripts/wsl-security-check.sh --monthly --project .
bash scripts/wsl-security-check.sh --preflight --project .
```

Review the latest summary:

```bash
latest="$(ls -td ~/.local/state/wsl-security/* | head -1)"
cat "$latest/summary.json"
```

## Automation with systemd

If `systemd=true` is enabled in `/etc/wsl.conf`, you can use a systemd user timer.

Create `~/.config/systemd/user/aegis-skills-daily.service`:

```ini
[Unit]
Description=Aegis Skills Daily Security Check

[Service]
Type=oneshot
ExecStart=%h/code/agentic-linux-wsl-kit/scripts/wsl-security-check.sh --daily
```

Create `~/.config/systemd/user/aegis-skills-daily.timer`:

```ini
[Unit]
Description=Run Aegis Skills Daily Security Check

[Timer]
OnCalendar=daily
Persistent=true

[Install]
WantedBy=timers.target
```

Enable and start:

```bash
systemctl --user daemon-reload
systemctl --user enable --now aegis-skills-daily.timer
```

## Handling findings

1. Review `~/.local/state/wsl-security/<run-id>/summary.json`.
2. Inspect referenced log files in the same run directory.
3. Draft a fix plan.
4. Execute approved fixes with the relevant Aegis Skills workflow.
5. Re-run the check and compare before/after evidence.

## Safety principles

- Do not allow the routine to auto-fix issues.
- Do not store raw secrets in logs.
- Use redaction for secret scanners where available.
- Use non-interactive `sudo -n` only where explicitly intended.
- Treat `summary.json` as the machine-readable source of truth.
