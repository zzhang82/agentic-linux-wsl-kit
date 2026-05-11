param(
  [Parameter(Mandatory=$true)][string]$DistroName,
  [Parameter(Mandatory=$true)][string]$BackupDir
)

$ErrorActionPreference = "Stop"
New-Item -ItemType Directory -Force -Path $BackupDir | Out-Null
$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
$target = Join-Path $BackupDir "$DistroName-$stamp.tar"

Write-Host "Exporting WSL distro '$DistroName' to '$target'"
Write-Host "Recommended: run 'wsl --shutdown' before this command from Windows PowerShell."
wsl --export $DistroName $target
Write-Host "Export complete: $target"
