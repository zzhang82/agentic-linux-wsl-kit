# Project overview

Agentic Linux WSL Kit is a safe-by-default operating layer for LLM coding agents working inside Linux/WSL.

The repository combines agent-readable `SKILL.md` playbooks with deterministic scripts. The design goal is simple: agents can collect evidence and propose changes, but risky actions are previewed, gated, or intercepted.

## Architecture

```text
Agent request
  -> skill playbook
  -> deterministic script
  -> evidence output
  -> human approval when risk exists
  -> guarded execution
  -> validation after
```

For package-manager operations, the flow is stricter:

```text
npm/pnpm/yarn/bun/npx command
  -> safe-* wrapper
  -> node-supply-chain-guard
  -> preflight checks
  -> lifecycle script review
  -> human approval
  -> isolated execution
  -> postinstall scan
```

## MVPs delivered

### MVP1: linux-doctor

Read-only Linux/WSL diagnostics.

```bash
bash scripts/linux-doctor.sh
bash scripts/linux-doctor.sh --format json
```

Checks include OS/kernel, WSL/systemd, PATH, required and recommended tools, package manager health, Docker daemon reachability, and secret directory metadata.

### MVP2: package-security-update

Safe package/security checks and approved updates.

```bash
bash scripts/package-security-check.sh
bash scripts/package-security-update.sh --preview
bash scripts/package-security-update.sh --apply
```

Workflow:

```text
baseline doctor -> package check -> summarize changes -> human approval -> apply -> doctor after
```

### MVP3: wsl-version-migration

Rollback-safe WSL distro migration workflow.

```text
inventory -> backup/export -> install target -> bootstrap -> migrate selected data -> validate -> cutover
```

`wsl --unregister` is intentionally not automated.

### MVP4: wsl-security-routine

Recurring read-only security posture checks with structured evidence.

```bash
bash scripts/wsl-security-check.sh --daily
bash scripts/wsl-security-check.sh --weekly --project .
bash scripts/wsl-security-check.sh --monthly --project .
bash scripts/wsl-security-check.sh --preflight --project .
bash scripts/wsl-security-check.sh --list-tools
```

Outputs are saved under:

```text
~/.local/state/wsl-security/<mode>-<timestamp>/
```

Important outputs:

```text
manifest.json
linux-doctor.ndjson
package-check.ndjson
summary.json
trivy-fs.json
grype.json
trufflehog.json
```

### MVP5: node-supply-chain-guard

Active defense for package-manager operations.

```bash
bash scripts/node-supply-chain-guard.sh --preinstall --project .
bash scripts/node-supply-chain-guard.sh --list-scripts --project .
bash scripts/node-supply-chain-guard.sh --request "npm install axios" --project .
bash scripts/node-supply-chain-guard.sh --execute-approved npm-ci --project .
bash scripts/node-supply-chain-guard.sh --postinstall-scan --project .
```

The guard blocks raw installs, checks registry and lockfile state, reviews lifecycle scripts, requires approval, executes in a stripped environment, and scans after install.

## Skills included

```text
skills/
  linux-doctor/
  package-security-update/
  wsl-version-migration/
  wsl-security-routine/
  node-supply-chain-guard/
```

## Safety model

```text
default mode: read-only / preview / blocked
secret policy: metadata only, never contents
updates: explicit --apply required
package installs: intercepted and guard-owned
package scripts: ignored unless explicitly reviewed
execution environment: env -i + temp HOME + restricted PATH
migrations: rollback first, destructive actions manual
validation: every checkpoint produces evidence
```

## Common workflows

### Before an agent starts coding

```bash
bash scripts/wsl-security-check.sh --preflight --project .
```

### Before accepting a new dependency

```bash
bash scripts/node-supply-chain-guard.sh --preinstall --project .
bash scripts/node-supply-chain-guard.sh --list-scripts --project .
bash scripts/node-supply-chain-guard.sh --request "npm install <package>" --project .
```

### Weekly maintenance

```bash
bash scripts/wsl-security-check.sh --weekly --project .
```

### Monthly deep scan

```bash
bash scripts/wsl-security-check.sh --monthly --project .
```

## Possible next milestone

MVP6: containerized package quarantine. Run suspicious dependency operations in disposable containers with read-only project mounts and no access to the real WSL home directory.
