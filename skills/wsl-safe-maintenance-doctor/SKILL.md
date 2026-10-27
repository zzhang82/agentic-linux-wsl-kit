---
name: wsl-safe-maintenance-doctor
version: 0.1.0
description: Use when auditing or planning routine WSL/Linux maintenance, disk cleanup, package updates, cache or journal cleanup, Docker storage cleanup, or WSL distro compaction. Runs a read-only evidence and classification pass first, separates Linux-side and Windows-side actions, and requires exact approval plus rollback evidence before any mutation.
---

# WSL Safe Maintenance Doctor

Audit first. Classify what is active, reviewable, or approval-gated. Do not optimize by deleting broadly.

## Workflow

```text
Audit
  -> Linux/WSL health, disk, packages, caches, journals, Docker, home-root sizes
Classify
  -> KEEP_ACTIVE / REVIEW / APPROVAL_REQUIRED
Approve
  -> exact action ids, paths/packages/containers, risk, expected result
Backup
  -> action-specific rollback evidence before mutation
Dry-run
  -> exact commands and targets
Apply
  -> one approved action family at a time
Validate
  -> health, package state, services, Docker, disk, WSL restart
Closeout
  -> reports, rollback instructions, remaining risks
```

The current implementation covers **Audit** and **Classify** only.

## Audit Command

```bash
python3 scripts/wsl-maintenance-audit.py
```

Specify an output directory when the caller needs deterministic artifact paths:

```bash
python3 scripts/wsl-maintenance-audit.py --output /tmp/wsl-maintenance-audit
```

Use `--quick` only for smoke tests; it skips full home-root sizing.

## Evidence Contract

The audit writes:

- `audit.json`: structured evidence, command outcomes, and classifications.
- `report.md`: human-readable findings and explicit no-action boundaries.

Both artifacts are written with owner-only `0600` permissions. The audit refuses existing artifacts and output paths with pre-existing symlink components; this is not a comprehensive same-user TOCTOU guarantee. Treat `audit.json` as operationally sensitive metadata even though it must not contain secret contents.

Report at minimum:

- OS, kernel, WSL detection, systemd, `dpkg --audit`, and failed units.
- Local package upgrade count without refreshing package metadata.
- Distro and Windows-mounted disk usage, with a warning that Linux free space is not the host VHD file size.
- APT cache, journal, and selected developer-cache sizes.
- Docker daemon reachability, storage summary, and exact stopped-container metadata.
- Explicit completeness for Docker executable availability, daemon reachability, container listing, container inspection, and storage summary.
- Immediate home-root names and sizes only; never print file contents. Protected credential/config/runtime roots are listed by bounded metadata and are not recursively traversed.
- Classification and the smallest safe next action.

## Composition Rules

- Use `linux-doctor` for the baseline environment diagnosis.
- Use `wsl-home-hygiene` (when installed in the agent environment) for targeted home-root cleanup classification.
- Use `package-security-update` only after package actions are approved and narrowed.
- Use `wsl-security-routine` when the request is security posture rather than routine maintenance.
- Use `wsl-version-migration` for export, migration, cutover, or distro retirement.

## Redlines

- Never use `sudo`, `apt-get update`, `apt upgrade`, `autoremove`, cache cleaning, journal vacuum, Docker removal/prune, or home deletion during audit.
- Never run generic `docker system prune` under this skill.
- Never classify a large active directory as junk from size alone.
- Never print secret contents or recursively inspect credential stores.
- Never run `wsl --shutdown`, export, unregister, sparse-VHD operations, or compaction without a separate Windows-side plan and explicit approval.
- Never claim VHD host-space recovery from Linux filesystem free-space evidence alone.

## Approval Boundary

After audit, present exact proposed actions. Each mutation needs:

- action id and target
- current evidence and risk
- expected effect
- rollback or recovery plan
- dry-run command
- explicit user approval

Read `references/classification-policy.md` when interpreting thresholds or drafting an approval manifest.

## Validation

- Confirm the audit manifest says `read_only: true`.
- Confirm no direct argv command evaluated by the audit guard begins with `sudo` or belongs to its supported mutation denylist. The guard does not parse shell-wrapped PowerShell or arbitrary generic home-deletion commands.
- Confirm safety claims are derived from the command ledger, not hard-coded assertions.
- Confirm protected home roots were not recursively traversed and artifacts are mode `0600`.
- Treat missing or failed evidence as `REVIEW`, never as healthy zero state.
- Validate `audit.json` parses.
- Compare reported package, disk, and Docker evidence with direct read-only commands when making consequential recommendations.
- Keep Windows-side restart or compaction validation pending until it actually occurs.
