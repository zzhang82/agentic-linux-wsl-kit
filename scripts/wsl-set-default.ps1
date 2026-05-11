param(
  [Parameter(Mandatory=$true)][string]$DistroName
)

$ErrorActionPreference = "Stop"
Write-Host "Setting default WSL distro to '$DistroName'"
wsl --set-default $DistroName
wsl -l -v
