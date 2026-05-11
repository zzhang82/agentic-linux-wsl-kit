#!/usr/bin/env bash
set -Eeuo pipefail

usage() {
  cat <<'EOF'
package-security-check.sh - read-only package and security posture check

Usage:
  scripts/package-security-check.sh [--no-network] [--help]

Default mode may refresh package metadata with apt-get update when sudo is available.
--no-network skips metadata refresh and package manager network operations.
EOF
}

NO_NETWORK=0
while [ "${1:-}" != "" ]; do
  case "$1" in
    --no-network) NO_NETWORK=1; shift ;;
    --help|-h) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage >&2; exit 2 ;;
  esac
done

section() { printf '\n== %s ==\n' "$1"; }

section "apt health"
if ! command -v apt-get >/dev/null 2>&1; then
  echo "WARN apt-get not found; unsupported package manager for this MVP"
  exit 0
fi

if [ "$NO_NETWORK" -eq 0 ]; then
  if sudo -n true 2>/dev/null; then
    sudo apt-get update
  else
    echo "WARN sudo without prompt is unavailable; skipping apt-get update"
  fi
else
  echo "INFO --no-network set; skipping apt-get update"
fi

echo "dpkg audit lines: $(dpkg --audit | wc -l)"

section "upgradable packages"
apt list --upgradable 2>/dev/null || true

section "security-related tools"
dpkg-query -W unattended-upgrades apt-listchanges 2>/dev/null || true
systemctl list-timers apt-daily.timer apt-daily-upgrade.timer --no-pager 2>/dev/null || true

section "language ecosystem audits"
if command -v npm >/dev/null 2>&1 && [ -f package-lock.json ]; then
  npm audit --omit=dev || true
else
  echo "INFO npm audit skipped: no package-lock.json in current directory or npm missing"
fi
if command -v uv >/dev/null 2>&1 && [ -f pyproject.toml ]; then
  echo "INFO Python project detected; consider: uv run pip-audit (if pip-audit is configured)"
fi

section "summary"
echo "Read-only check complete. Use package-security-update.sh --apply for approved updates."
