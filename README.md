# Agentic Linux WSL Kit

Open-source skills and scripts for LLM-assisted Linux/WSL diagnostics, safe package/security updates, and rollback-safe WSL distro migrations.

> Status: MVP1-MVP3 scaffold is publish-ready for review. Scripts default to read-only or preview unless explicitly named otherwise.

![Agentic Linux WSL Kit architecture](assets/agentic-linux-wsl-kit-architecture.svg)

## Why this exists

LLM coding agents are useful only when the local environment is understandable, reproducible, and safe to change. This kit gives agents and humans a shared operating model:

- collect evidence before changing anything;
- avoid printing secrets;
- prefer read-only diagnostics and preview modes;
- preserve rollback before WSL migrations;
- validate after each checkpoint.

## Core architecture

```text
                 user / agent request
                         |
                         v
              +-----------------------+
              |   skill instructions  |
              |  SKILL.md playbooks   |
              +-----------+-----------+
                          |
          +---------------+----------------+
          |               |                |
          v               v                v
  +---------------+ +----------------+ +-------------------+
  | linux-doctor  | | package-       | | wsl-version-      |
  | read-only     | | security-update| | migration         |
  | evidence      | | preview/apply  | | rollback/cutover  |
  +-------+-------+ +--------+-------+ +---------+---------+
          |                  |                   |
          +------------------+-------------------+
                             |
                             v
              +-----------------------------+
              | validation + human decision |
              | no secrets, no guessing     |
              +-----------------------------+
```

## Skills

```text
skills/
  linux-doctor/
    SKILL.md                  # read-only diagnostic workflow
  package-security-update/
    SKILL.md                  # safe update workflow with preview/apply
  wsl-version-migration/
    SKILL.md                  # rollback-safe WSL migration workflow
```

### MVP1: linux-doctor

Use when you need an LLM-friendly diagnosis of Linux/WSL health.

```bash
scripts/linux-doctor.sh
scripts/linux-doctor.sh --format json
```

Checks include OS/kernel, WSL/systemd, PATH, required/recommended tools, package manager health, Docker daemon reachability, and secret directory metadata.

### MVP2: package-security-update

Use when you want safe package/security checks or approved updates.

```bash
scripts/package-security-check.sh
scripts/package-security-update.sh --preview
scripts/package-security-update.sh --apply
scripts/package-security-update.sh --apply --language-tools
```

Process map:

```text
doctor baseline
  -> package-security-check
  -> summarize pending changes
  -> human approval
  -> package-security-update --apply
  -> doctor after update
```

### MVP3: wsl-version-migration

Use when moving between WSL distro versions, such as Ubuntu 22.04 to 24.04.

```text
inventory -> backup/export -> install target -> bootstrap
  -> migrate selected data -> validate -> set default -> optional retire old distro
```

Important: `wsl --unregister` is intentionally not automated. The human must explicitly name and confirm the distro to remove.

## Install / use locally

Clone the repo:

```bash
git clone https://github.com/zzhang82/agentic-linux-wsl-kit.git
cd agentic-linux-wsl-kit
```

Run a doctor check:

```bash
bash scripts/linux-doctor.sh
```

Run validation tests:

```bash
bash tests/smoke.sh
```

Optional: install skills into an OpenCode/Claude-compatible skills directory by copying each skill folder to your user skills path. Keep project-specific goals outside this repo.

## Repository layout

```text
agentic-linux-wsl-kit/
  README.md
  LICENSE
  SECURITY.md
  CONTRIBUTING.md
  skills/
  scripts/
  docs/
  assets/
  tests/
```

## Safety model

```text
default mode: read-only / preview
secret policy: metadata only, never contents
updates: explicit --apply required
migrations: rollback first, destructive actions manual
validation: every checkpoint produces evidence
```

See [docs/threat-model.md](docs/threat-model.md) and [docs/recovery.md](docs/recovery.md).

## Supported platforms

Primary target:

- Ubuntu on WSL2, especially Ubuntu 22.04/24.04.

Best-effort:

- Ubuntu/Debian-like Linux environments with `apt`.

Not yet supported:

- Fedora/RHEL package workflows.
- macOS package workflows.
- Fully automated WSL unregister/import orchestration.

## Skill authoring baseline

This repo follows the common `SKILL.md` pattern used by modern coding agents:

- YAML frontmatter with `name`, `description`, and `version`.
- Specific trigger phrases in the description.
- Short primary instructions in `SKILL.md`.
- Scripts kept deterministic and separately testable.

## License

MIT. See [LICENSE](LICENSE).
