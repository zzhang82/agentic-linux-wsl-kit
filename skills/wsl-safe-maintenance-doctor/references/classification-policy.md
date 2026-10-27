# WSL Maintenance Classification Policy

## Classes

| Class | Meaning | Default action |
| --- | --- | --- |
| `KEEP_ACTIVE` | Healthy state or active configuration/data | Leave unchanged |
| `REVIEW` | Potential maintenance opportunity needing user/context review | Investigate exact target; do not mutate |
| `APPROVAL_REQUIRED` | A concrete state-changing action is available | Create approval and rollback artifacts before apply |

## Audit Thresholds

Thresholds identify review candidates, not automatic deletion targets.

- Root filesystem use below 80%: `KEEP_ACTIVE`.
- Root filesystem use 80-89%: `REVIEW`.
- Root filesystem use 90% or more: `APPROVAL_REQUIRED` for a bounded capacity plan.
- Windows C: mount use at or above 80%: `REVIEW` and hand off to a Windows-side storage audit; do not translate it into Linux cleanup approval.
- APT cache below 256 MiB: `KEEP_ACTIVE`; at or above 256 MiB: `REVIEW`.
- Journals below 512 MiB: `KEEP_ACTIVE`; at or above 512 MiB: `REVIEW`.
- Individual developer caches at or above 1 GiB: `REVIEW`.
- Any pending package update: `APPROVAL_REQUIRED` before package mutation.
- Any stopped Docker container with writable data: `REVIEW`; exact owner/purpose confirmation is required before removal.
- Any Docker image reclaim estimate: `REVIEW`; never translate it into permission for generic prune.

## Protected Home Entries

Default to `KEEP_ACTIVE` or `REVIEW`, never automatic cleanup:

- `.ssh`, `.gnupg`, `.aws`, `.config`, `.local`
- `.kube`, `.docker`, `.runtime-agents`, `.gemini`
- `.codex`, `.opencode`, `.hermes`, `.claude`, `.claude-code-router`
- `code`, `projects`, vaults, backups, local models, SDKs, and game/project data

Size alone is not evidence of staleness.
Protected credential/config/runtime roots must not be recursively traversed during the default audit.
Active project roots, vault backups, and known large user-data roots should also remain bounded metadata by default; use a targeted follow-up only when capacity evidence justifies it.

## Windows-Side WSL Boundary

Treat distro export, shutdown, filesystem preparation, sparse-VHD management, and VHD compaction as separate actions. Before compaction:

1. Verify exact distro identity.
2. Verify a rollback export when required by the risk level.
3. Confirm the export exists and is readable; record size and hash.
4. Stop active WSL and container work cleanly.
5. Dry-run or document the exact Windows-side command supported by the current host.
6. Obtain explicit approval.
7. Validate distro boot, filesystem health, services, and tools afterward.
