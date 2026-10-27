# Aegis Skills

[![Status](https://img.shields.io/badge/status-stable-brightgreen)](#)
[![Release](https://img.shields.io/badge/release-v1.0.0-blue)](#)
[![Platform](https://img.shields.io/badge/platform-WSL2%20%7C%20Ubuntu-blue)](#)
[![Safety](https://img.shields.io/badge/default-read--only%20%2F%20guarded-success)](#safety-model)
[![License](https://img.shields.io/badge/license-MIT-lightgrey)](LICENSE)

**Security automation skills and active defenses for Linux/WSL coding-agent environments.**

Aegis Skills is a battle-tested safety harness for human developers and autonomous coding agents (Cursor, Claude Code, Codex, and interactive shells). It enforces safe-by-default execution: diagnose before modifying, preview risky changes, intercept untrusted package manager commands, execute approved installs in isolation, and record verifiable, machine-readable evidence.

**Tags:** `llm-agents` · `coding-agents` · `devsecops` · `supply-chain-security` · `npm-security` · `wsl` · `linux` · `automation`

---

## Architecture

```text
                           Aegis Skills
                 Safe-by-Default Automation Layer

               Human or Agent Task Request
                           |
                           v
            +-------------------------------+
            | SKILL.md Playbooks & SOPs     |  Define scope, stop boundaries,
            | Reusable Agent Protocols      |  and evidence contracts
            +---------------+---------------+
                            |
            +---------------+---------------+
            |                               |
     [Operational Path]              [Package Manager Path]
            |                               |
            v                               v
+-----------------------+       +-------------------------------+
| Deterministic Scripts |       | Cooperative safe-* Wrappers   |  Intercepts npm, pnpm,
| - linux-doctor        |       | (PATH-based interception)     |  yarn, bun, and npx
| - maintenance-audit   |       +---------------+---------------+
| - security-check      |                       |
| - version-migration   |                       v
+-----------+-----------+       +-------------------------------+
            |                   | node-supply-chain-guard       |  Checks registries,
            |                   | Lifecycle script reviewer     |  lockfiles, & scripts
            |                   +---------------+---------------+
            |                                   |
            |                                   v
            |                   +-------------------------------+
            |                   | Explicit Approval Gate        |  Human reviews risk
            |                   +---------------+---------------+
            |                                   |
            |                                   v
            |                   +-------------------------------+
            |                   | Sanitized / Isolated Exec     |  temp HOME, clean PATH,
            |                   | --ignore-scripts enforcement  |  post-install scans
            |                   +---------------+---------------+
            v                                   |
    +-------------------------------------------+
    |
    v
+-------------------------------+
| Machine-Readable Evidence     |  summary.json, report.md, audit logs
| Owner-Only Permissions (0600) |  Strict fail-closed error propagation
+-------------------------------+
```

---

## Core Capabilities

| Capability | Module | Description | Entry Point |
|---|---|---|---|
| **Environment Diagnostics** | `linux-doctor` | Read-only audit of OS, kernel, WSL/systemd health, pure Linux PATH, command availability, and secret directory metadata. | `scripts/linux-doctor.sh` |
| **Gated Package Updates** | `package-security-update` | Offline package check with explicit approval gates before applying APT security upgrades. | `scripts/package-security-check.sh` |
| **Safe Maintenance Audit** | `wsl-safe-maintenance-doctor` | Non-destructive classification of root storage, Windows C: pressure, Docker layers, journals, and developer caches. | `scripts/wsl-maintenance-audit.py` |
| **Supply Chain Guard** | `node-supply-chain-guard` | Intercepts dangerous package manager lifecycle scripts and runs approved installs under sanitized environments. | `scripts/node-supply-chain-guard.sh` |
| **Command Interception** | `aegis-trigger-layer` | Unified dispatcher connecting preflight checks, git hooks, and safe command wrappers. | `scripts/aegis-trigger.sh` |
| **Security Routines** | `wsl-security-routine` | Scheduled posture scans, SBOM generation, and secret detection with strict error propagation. | `scripts/wsl-security-check.sh` |
| **WSL Distro Migration** | `wsl-version-migration` | Rollback-safe distro upgrade and export/import workflows with automated inventory checks. | `scripts/wsl-inventory.sh` |

---

## Quick Start

```bash
git clone https://github.com/zzhang82/agentic-linux-wsl-kit.git
cd agentic-linux-wsl-kit
bash tests/smoke.sh
```

### 1. Install Trigger Harness & Command Wrappers

Install safe command interceptors and git hooks to your user environment:

```bash
bash scripts/install-aegis-triggers.sh --all
```

This symlinks `safe-*.sh` wrappers into `~/.local/bin/` to intercept common risky commands (`npm install`, `npm ci`, `pnpm add`, `yarn`, `bun add`, `npx`) and route them through security review.

### 2. Launch a Protected Agent Session

Run coding agents or shells through the Aegis front door:

```bash
bash scripts/aegis-agent-session.sh --project . -- agent-local
```

Before your agent session begins, Aegis runs a preflight security check (scanning for secrets and verifying environment integrity) and sets up the active wrapper PATH.

---

## Safety Model & Invariants

1. **Read-Only by Default:** Diagnostic and audit scripts (`linux-doctor`, `package-security-check`, `wsl-maintenance-audit`) never mutate files, install packages, or clean caches without explicit, separate approval.
2. **Private Evidence Storage:** All generated audit manifests and security outputs are stored in owner-only directories (`0700`) with restricted file modes (`0600`).
3. **Fail-Closed Preflights:** Scanner runtime failures or secret detections block agent session startup in strict mode.
4. **Cooperative Interception Boundary:** Aegis operates as a cooperative layer for agent and interactive terminal sessions via PATH wrappers and preflight hooks. Absolute container isolation and disposable quarantine represent the next stage of active defense.
5. **No Secret Disclosure:** Secrets are redacted in scanner outputs where supported; secret files are inspected for metadata/permissions only and contents are never printed.

---

## Documentation

- [Project Overview](docs/project-overview.md)
- [Active Defense Strategy](docs/agent-active-defense.md)
- [Node & npm Supply-Chain Policy](docs/npm-supply-chain-policy.md)
- [Security Routine SOP](docs/security-routine-sop.md)
- [Threat Model](docs/threat-model.md)
- [Recovery Guide](docs/recovery.md)

---

## License

MIT. See [LICENSE](LICENSE).
