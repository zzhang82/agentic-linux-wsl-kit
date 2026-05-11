param(
  [string]$DistroName = "Ubuntu-24.04",
  [switch]$NoLaunch
)

$ErrorActionPreference = "Stop"
$args = @("--install", $DistroName)
if ($NoLaunch) { $args += "--no-launch" }
Write-Host "Installing WSL distro: $DistroName"
wsl @args
Write-Host "Install command completed. Run validation before cutover."
