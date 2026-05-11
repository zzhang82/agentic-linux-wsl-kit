---
name: wsl-version-migration
description: This skill should be used when the user asks to "migrate WSL to Ubuntu 24.04", "upgrade WSL distro safely", "move between Ubuntu WSL versions", "export my old WSL distro", "create a rollback-safe WSL migration", or validate a new WSL distro before cutover. It requires checkpoints and explicit human confirmation for destructive actions such as unregistering a distro.
version: 0.1.0
---

# WSL Version Migration

Plan and execute rollback-safe WSL distro migrations between Ubuntu versions.

## Hard Safety Rules

- Never run `wsl --unregister` automatically.
- Never assume the current distro is safe to delete.
- Export or otherwise preserve rollback before cutover.
- Prefer fresh install plus selected migration over copying stale runtimes/caches.
- Do not print secret contents; migrate secrets only as files with safe permissions or ask the user to re-authenticate.
- Run Windows-side export commands from Windows PowerShell where possible, especially after `wsl --shutdown`.

## Checkpoint Flow

```text
1. Inventory source distro
   -> scripts/wsl-inventory.sh

2. Backup/export rollback image
   -> scripts/wsl-export-backup.ps1 from Windows PowerShell

3. Install target distro
   -> scripts/wsl-install-ubuntu.ps1

4. Bootstrap target baseline
   -> apt packages, systemd, clean PATH, language runtimes

5. Migrate selected data
   -> projects/configs only, exclude caches and stale runtimes

6. Validate target distro
   -> scripts/wsl-validate.sh + project-specific checks

7. Cut over default distro
   -> scripts/wsl-set-default.ps1

8. Retire old distro only after explicit human confirmation
   -> manual `wsl --unregister <old>`
```

## Recommended Evidence

- `wsl -l -v` before and after.
- Target OS version and WSL version.
- `/etc/wsl.conf` target settings.
- Toolchain versions.
- Docker strategy and daemon status.
- Secret metadata only.
- Archive readability check for exports.

## Stop Conditions

- Backup/export cannot be verified.
- Target distro validation fails.
- Required credentials are missing and cannot be re-authenticated.
- User asks for destructive action without naming the exact distro.
