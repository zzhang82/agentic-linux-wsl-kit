---
name: package-security-update
description: This skill should be used when the user asks to "check Linux package updates", "secure my WSL packages", "update apt safely", "audit package security", or refresh Python/Node/AI CLI tooling after reviewing pending changes. It previews by default and requires explicit approval before applying updates.
version: 0.1.0
---

# Package Security Update

Audit and safely update Linux/WSL package layers with a before/after doctor check.

## Safety Rules

- Start with read-only or preview mode.
- Do not run release upgrades or distro migrations.
- Do not remove packages except normal `apt-get autoremove` after explicit `--apply`.
- Do not change major language runtime strategy unless the user explicitly requests it.
- Do not print auth tokens or cloud credentials.

## Workflow

```text
package/security request
  -> run linux-doctor baseline
  -> run package-security-check
  -> summarize pending updates / package health
  -> ask for approval when changes are needed
  -> run package-security-update --apply only after approval
  -> run linux-doctor after update
```

## Commands

Preview/check:

```bash
scripts/package-security-check.sh
scripts/package-security-update.sh --preview
```

Apply OS packages only:

```bash
scripts/package-security-update.sh --apply
```

Apply OS packages plus opt-in language/tool CLIs:

```bash
scripts/package-security-update.sh --apply --language-tools
```

## Evidence to Report

- `dpkg --audit` count.
- Upgradable package list summary.
- unattended-upgrades/timer status when systemd is present.
- npm audit results when run in a JS project.
- Python audit recommendation when a Python project is detected.
- Doctor before/after summary.
