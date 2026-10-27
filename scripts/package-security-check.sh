#!/usr/bin/env bash
set -Eeuo pipefail

usage() {
  cat <<'EOF'
package-security-check.sh - read-only package and security posture check

Usage:
  scripts/package-security-check.sh [--refresh-metadata] [--no-network] [--format text|json] [--help]

Options:
  --refresh-metadata  Explicitly refresh package metadata with apt-get update (requires sudo).
  --no-network        Skip all network-dependent operations and checks.
  --format text|json  Output format (default: text).
  --help, -h          Show this help.

By default, the check is strictly read-only and uses local repository metadata.
EOF
}

REFRESH_METADATA=0
NO_NETWORK=0
FORMAT="text"
while [ "${1:-}" != "" ]; do
  case "$1" in
    --refresh-metadata|--refresh) REFRESH_METADATA=1; shift ;;
    --no-network) NO_NETWORK=1; shift ;;
    --format) FORMAT="${2:-text}"; shift 2 ;;
    --help|-h) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage >&2; exit 2 ;;
  esac
done

json_escape() { python3 -c 'import json,sys; print(json.dumps(sys.stdin.read().rstrip("\n")))'; }

status_line() {
  local level="$1" area="$2" msg="$3"
  if [ "$FORMAT" = "text" ]; then
    printf '%-5s %-22s %s\n' "$level" "$area" "$msg"
  else
    printf '{"level":%s,"area":%s,"message":%s}\n' \
      "$(printf '%s' "$level" | json_escape)" \
      "$(printf '%s' "$area" | json_escape)" \
      "$(printf '%s' "$msg" | json_escape)"
  fi
}

section() {
  if [ "$FORMAT" = "text" ]; then
    printf '\n== %s ==\n' "$1"
  fi
}

section "apt health"
if ! command -v apt-get >/dev/null 2>&1; then
  status_line WARN apt "apt-get not found; unsupported package manager for this MVP"
  exit 0
fi

if [ "$REFRESH_METADATA" -eq 1 ] && [ "$NO_NETWORK" -eq 0 ]; then
  if sudo -n true 2>/dev/null; then
    sudo apt-get update >/dev/null 2>&1
    status_line INFO apt "metadata refreshed"
  else
    status_line WARN apt "sudo without prompt is unavailable; skipping apt-get update"
  fi
elif [ "$REFRESH_METADATA" -eq 1 ] && [ "$NO_NETWORK" -eq 1 ]; then
  status_line INFO apt "skipping update (no-network requested)"
else
  status_line INFO apt "using local package metadata (pass --refresh-metadata to update)"
fi

audit_count="$(dpkg --audit 2>/dev/null | wc -l || echo "0")"
status_line INFO dpkg "audit lines: $audit_count"

section "upgradable packages"
if [ "$FORMAT" = "text" ]; then
  apt list --upgradable 2>/dev/null || true
else
  if upgradable_raw="$(apt list --upgradable 2>&1)"; then
    upgradable_count="$(printf '%s\n' "$upgradable_raw" | grep -c '/' || true)"
    status_line INFO apt "upgradable packages: $upgradable_count"
  else
    status_line WARN apt "could not query upgradable packages"
  fi
fi

section "security-related tools"
if [ "$FORMAT" = "text" ]; then
  dpkg-query -W unattended-upgrades apt-listchanges 2>/dev/null || true
  systemctl list-timers apt-daily.timer apt-daily-upgrade.timer --no-pager 2>/dev/null || true
fi

section "language ecosystem audits"
if [ "$NO_NETWORK" -eq 1 ] || [ "$REFRESH_METADATA" -eq 0 ]; then
  status_line INFO ecosystem "skipped language ecosystem network checks (pass --refresh-metadata to query online registries)"
else
  if command -v npm >/dev/null 2>&1 && [ -f package-lock.json ]; then
    if [ "$FORMAT" = "text" ]; then
      npm audit --omit=dev 2>/dev/null || true
    else
      status_line INFO npm "package-lock.json detected; run npm audit for details"
    fi
  else
    status_line INFO npm "skipped: no package-lock.json or npm missing"
  fi
  if command -v uv >/dev/null 2>&1 && [ -f pyproject.toml ]; then
    status_line INFO uv "Python project detected; consider: uv run pip-audit"
  fi
fi

section "summary"
if [ "$FORMAT" = "text" ]; then
  echo "Read-only check complete. Use package-security-update.sh --apply for approved updates."
else
  status_line OK summary "Read-only check complete."
fi
