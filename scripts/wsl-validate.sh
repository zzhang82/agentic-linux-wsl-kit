#!/usr/bin/env bash
set -Eeuo pipefail

echo "== WSL/Linux validation =="
"$(dirname "$0")/linux-doctor.sh"

echo "== WSL command visibility =="
if command -v wsl.exe >/dev/null 2>&1; then
  wsl.exe -l -v || true
elif [ -x /mnt/c/Windows/System32/wsl.exe ]; then
  /mnt/c/Windows/System32/wsl.exe -l -v || true
else
  echo "INFO wsl.exe not visible from this environment"
fi
