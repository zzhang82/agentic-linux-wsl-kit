---
name: linux-doctor
description: This skill should be used when the user asks to "diagnose my Linux environment", "check my WSL coding setup", "run doctor mode", "identify Linux/WSL issues for an LLM", or troubleshoot PATH, systemd, package manager, Docker, Python, Node, cloud CLI, or agent CLI health. It is read-only by default and must not print secret contents.
version: 0.1.0
---

# Linux Doctor

Run a read-only, evidence-first diagnostic pass for Linux/WSL coding environments.

## Safety Rules

- Do not modify system state.
- Do not print secret contents.
- Report credential-like files by metadata only: path, mode, size, owner if needed.
- Prefer commands that work without sudo.
- If sudo is required for a proposed fix, stop and ask before running it.

## Workflow

```text
user symptom / health check request
  -> identify environment: Linux, WSL, container, CI
  -> run read-only checks
  -> classify findings: OK / WARN / FAIL
  -> explain likely causes
  -> propose smallest safe next action
```

## Recommended Command

```bash
scripts/linux-doctor.sh
```

Use JSON-ish line output when downstream tooling needs structured records:

```bash
scripts/linux-doctor.sh --format json
```

## Evidence to Collect

- OS and kernel.
- WSL detection and `/etc/wsl.conf` settings.
- systemd state.
- PATH ordering and Windows PATH injection.
- Required/recommended command presence.
- Key tool versions.
- `dpkg --audit` count.
- Docker daemon reachability.
- Secret directory metadata without contents.

## Output Contract

Every diagnosis should include:

- Status: `OK`, `WARN`, or `FAIL`.
- Evidence: exact command output or summarized script findings.
- Risk: what might break.
- Next action: one or more safe commands.
- Stop reason: when a fix would require sudo, destructive actions, or credential access.
