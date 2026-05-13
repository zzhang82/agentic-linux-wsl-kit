# Security Routine Standard Operating Procedure (SOP)

This document outlines the standard operating procedure for running security checks in the Agentic Linux WSL environment.

## Overview

The security routine is a read-only process designed to provide visibility into the system's security posture without making automated changes. It uses a tiered approach (Daily, Weekly, Monthly) to balance thoroughness with execution time and resource usage.

## Routine Schedule

| Frequency | Mode | Purpose |
| :--- | :--- | :--- |
| **Daily** | `--daily` | Baseline check for OS health and secret directory permissions. No network. |
| **Weekly** | `--weekly` | Network-enabled check including system hardening (Lynis) and repo secret scanning (Gitleaks). |
| **Monthly** | `--monthly` | Deep dive including SBOM generation and comprehensive vulnerability scanning. |
| **Pre-coding**| `--preflight`| Fast check on the active repository before an agent begins work. |

## How to Run

### Manual Execution

Run the driver script from the repository root:

```bash
bash scripts/wsl-security-check.sh --daily
```

### Automation (systemd)

If `systemd=true` is enabled in `/etc/wsl.conf`, you can use a systemd user timer:

1. Create `~/.config/systemd/user/wsl-security-daily.service`:
   ```ini
   [Unit]
   Description=WSL Daily Security Check

   [Service]
   Type=oneshot
   ExecStart=%h/code/agentic-linux-wsl-kit/scripts/wsl-security-check.sh --daily
   ```

2. Create `~/.config/systemd/user/wsl-security-daily.timer`:
   ```ini
   [Unit]
   Description=Run WSL Daily Security Check

   [Timer]
   OnCalendar=daily
   Persistent=true

   [Install]
   WantedBy=timers.target
   ```

3. Enable and start:
   ```bash
   systemctl --user daemon-reload
   systemctl --user enable --now wsl-security-daily.timer
   ```

## Handling Findings

1. **Review the Summary**: Check `~/.local/state/wsl-security/<run-id>/summary.json`.
2. **Investigate WARN/FAIL**: Look at the specific log files in the run directory.
3. **Draft a Fix Plan**: Create a manual plan to address the findings.
4. **Execute approved fixes**: Use specialized skills like `package-security-update` for patching.

## Safety Principles

- Never allow the routine to auto-fix issues.
- Never store raw secrets in the logs.
- Always use `--redact` with Gitleaks.
- If a check requires `sudo`, it should only be run in modes where the user is present to approve or via non-interactive sudo if specifically configured and approved.
