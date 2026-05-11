# Examples

## Diagnose a WSL coding environment

```bash
scripts/linux-doctor.sh
```

## Generate structured diagnostic lines

```bash
scripts/linux-doctor.sh --format json
```

## Preview package updates

```bash
scripts/package-security-check.sh
scripts/package-security-update.sh --preview
```

## Apply reviewed package updates

```bash
scripts/package-security-update.sh --apply
```

## Inventory a source WSL distro before migration

```bash
scripts/wsl-inventory.sh ~/wsl-migration-inventory
```

## Export a WSL distro from Windows PowerShell

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\wsl-export-backup.ps1 -DistroName Ubuntu -BackupDir D:\wsl-backups
```
