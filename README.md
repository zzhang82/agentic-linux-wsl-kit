# Aegis Skills

[![Status](https://img.shields.io/badge/status-publish--ready-brightgreen)](#)
[![Platform](https://img.shields.io/badge/platform-WSL2%20%7C%20Ubuntu-blue)](#)
[![Safety](https://img.shields.io/badge/default-read--only%20%2F%20guarded-success)](#safety-model)
[![License](https://img.shields.io/badge/license-MIT-lightgrey)](LICENSE)

**Secure automation skills for Linux/WSL and LLM coding-agent workflows.**

Aegis Skills is **not an agent**. It is a set of reusable skills, scripts, wrappers, and SOPs that existing agents or humans can run to keep Linux/WSL environments safer by default.

It helps agents diagnose first, preview risky changes, block unsafe package commands, run approved installs in isolation, and leave behind machine-readable evidence.

**Tags:** `llm-agents` · `coding-agents` · `devsecops` · `supply-chain-security` · `npm-security` · `wsl` · `linux` · `automation`

If Aegis Skills helps your agent workflow feel safer, a GitHub star helps others find it.

## How it works

```text
                 Aegis Skills
        safe-by-default automation layer

  human / existing agent request
              |
              v
  +-------------------------+
  | SKILL.md playbooks      |  what to run, when to stop,
  | reusable SOPs           |  what evidence to collect
  +-----------+-------------+
              |
              v
  +-------------------------+       normal ops path
  | deterministic scripts   |-------------------------------+
  +-----------+-------------+                               |
              |                                             v
              |        +----------------+   +-------------------------+
              |        | linux-doctor   |   | package-security-update |
              |        | wsl migration  |   | wsl-security-routine    |
              |        +----------------+   +-------------------------+
              |                                             |
              |                                             v
              |                                  summary.json + logs
              |
              |       package-manager path
              v
  +-------------------------+
  | safe-* wrappers         |  block npm/pnpm/yarn/bun/npx
  +-----------+-------------+
              |
              v
  +-------------------------+
  | node-supply-chain-guard |  registry + lockfile + scripts
  +-----------+-------------+
              |
              v
  +-------------------------+
  | approval gate           |  human reviews risk
  +-----------+-------------+
              |
              v
  +-------------------------+
  | isolated execution      |  env -i, temp HOME, restricted PATH
  +-----------+-------------+
              |
              v
  +-------------------------+
  | postinstall scan        |  gitleaks, trivy, grype/trufflehog
  +-------------------------+
```

## What it does

- **Diagnose Linux/WSL health** with read-only checks.
- **Preview package/security updates** before applying changes.
- **Guide rollback-safe WSL migration** workflows.
- **Run recurring security audits** with structured `summary.json` output.
- **Intercept risky npm/pnpm/yarn/bun/npx commands** via a unified trigger dispatcher.
- **Enforce safety at the workflow boundary** with local git hooks and session launchers.

## Quick start

```bash
git clone https://github.com/zzhang82/agentic-linux-wsl-kit.git
cd agentic-linux-wsl-kit
bash tests/smoke.sh
```

### Install the Safety Harness

Activate the trigger layers (wrappers and git hooks):

```bash
bash scripts/install-aegis-triggers.sh --all
```

### Launch a Safe Session

Use Aegis as the "front door" for your coding agent or shell:

```bash
bash scripts/aegis-agent-session.sh --project . -- opencode
```

This ensures a security preflight runs, safe wrappers are in the `PATH`, and all risky commands are intercepted.

## Included skills

```text
linux-doctor
package-security-update
wsl-version-migration
wsl-security-routine
node-supply-chain-guard
aegis-trigger-layer
```

## Safety model

```text
read-only by default
preview before mutation
explicit approval for risky actions
package installs are intercepted and guard-owned
secrets are never printed
validation produces evidence
```

## More docs

- [Project overview](docs/project-overview.md)
- [Active defense strategy](docs/agent-active-defense.md)
- [npm supply-chain policy](docs/npm-supply-chain-policy.md)
- [Security routine SOP](docs/security-routine-sop.md)
- [Threat model](docs/threat-model.md)
- [Recovery guide](docs/recovery.md)

## Status

MVP1-MVP5 are complete:

```text
MVP1 diagnostics
MVP2 safe package updates
MVP3 WSL migration workflow
MVP4 read-only security routine
MVP5 active package-operation defense
```

Possible next milestone: **MVP6 containerized package quarantine**.

## License

MIT. See [LICENSE](LICENSE).
