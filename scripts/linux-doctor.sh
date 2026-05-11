#!/usr/bin/env bash
set -Eeuo pipefail

VERSION="0.1.0"
WARN=0
FAIL=0
FORMAT="text"

usage() {
  cat <<'EOF'
linux-doctor.sh - read-only Linux/WSL coding environment diagnostics

Usage:
  scripts/linux-doctor.sh [--format text|json] [--help]

This script is read-only. It does not print secret contents.
EOF
}

while [ "${1:-}" != "" ]; do
  case "$1" in
    --format) FORMAT="${2:-text}"; shift 2 ;;
    --help|-h) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage >&2; exit 2 ;;
  esac
done

json_escape() { python3 -c 'import json,sys; print(json.dumps(sys.stdin.read().rstrip("\n")))'; }
have() { command -v "$1" >/dev/null 2>&1; }
cmd_path() { command -v "$1" 2>/dev/null || true; }

status_line() {
  local level="$1" area="$2" msg="$3"
  case "$level" in
    WARN) WARN=1 ;;
    FAIL) FAIL=1 ;;
  esac
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

section "system"
status_line INFO version "$VERSION"
if [ -r /etc/os-release ]; then
  # shellcheck source=/dev/null
  . /etc/os-release
  status_line INFO os "${PRETTY_NAME:-unknown}"
else
  status_line WARN os "/etc/os-release is not readable"
fi
status_line INFO kernel "$(uname -r)"
status_line INFO user "$(id -un) groups=$(id -nG)"

if grep -qi microsoft /proc/version 2>/dev/null; then
  status_line INFO wsl "WSL-like kernel detected"
  if [ -r /etc/wsl.conf ]; then
    if grep -q '^systemd=true$' /etc/wsl.conf; then
      status_line OK wsl.conf "systemd=true"
    else
      status_line WARN wsl.conf "systemd=true not found"
    fi
    if grep -q '^appendWindowsPath=false$' /etc/wsl.conf; then
      status_line OK wsl.conf "appendWindowsPath=false"
    else
      status_line WARN wsl.conf "appendWindowsPath=false not found"
    fi
  else
    status_line WARN wsl.conf "missing or unreadable"
  fi
fi

if have systemctl; then
  sr="$(systemctl is-system-running 2>/dev/null || true)"
  case "$sr" in running|degraded) status_line OK systemd "$sr" ;; *) status_line WARN systemd "systemctl state: ${sr:-unknown}" ;; esac
fi

section "path"
path_first="$(printf '%s' "${PATH:-}" | tr ':' '\n' | sed -n '1,8p' | paste -sd '|' -)"
status_line INFO path.first8 "$path_first"
case ":${PATH:-}:" in *":/mnt/c/Windows:"*|*":/mnt/c/Windows/System32:"*) status_line WARN path "Windows path entries detected" ;; *) status_line OK path "no obvious Windows PATH injection" ;; esac

section "commands"
required=(git curl jq rg python3)
recommended=(gh fd fzf tmux direnv make gcc g++ pkg-config uv pipx node npm pnpm corepack gcloud docker opencode claude gemini task-master)
for c in "${required[@]}"; do
  p="$(cmd_path "$c")"
  if [ -n "$p" ]; then
    status_line OK "cmd.$c" "$p"
  else
    status_line FAIL "cmd.$c" "missing required command"
  fi
done
for c in "${recommended[@]}"; do
  p="$(cmd_path "$c")"
  if [ -n "$p" ]; then
    status_line OK "cmd.$c" "$p"
  else
    status_line WARN "cmd.$c" "missing recommended command"
  fi
done

section "versions"
for spec in \
  "python3::python3 --version" \
  "uv::uv --version" \
  "node::node --version" \
  "npm::npm --version" \
  "pnpm::pnpm --version" \
  "git::git --version" \
  "gh::gh --version" \
  "gcloud::gcloud --version" \
  "docker::docker --version" \
  "opencode::opencode --version"; do
  name="${spec%%::*}"; cmd="${spec#*::}"
  if have "$name"; then status_line INFO "version.$name" "$(bash -lc "$cmd" 2>/dev/null | sed -n '1p')"; fi
done

section "packages"
if have dpkg; then
  audit_count="$(dpkg --audit | wc -l)"
  if [ "$audit_count" = "0" ]; then
    status_line OK dpkg.audit "0"
  else
    status_line WARN dpkg.audit "$audit_count issue lines"
  fi
fi
if have apt-get; then
  status_line INFO apt "apt-get available; run package-security-check.sh for update/security details"
fi

section "services"
if have docker; then
  if have systemctl; then
    status_line INFO docker.service "$(systemctl is-active docker 2>/dev/null || true) / $(systemctl is-enabled docker 2>/dev/null || true)"
  fi
  if docker info >/dev/null 2>&1; then
    status_line OK docker.daemon "reachable"
  else
    status_line WARN docker.daemon "not reachable by current user/session"
  fi
fi

section "secrets metadata"
for d in "$HOME/.ssh" "$HOME/.gnupg" "$HOME/.aws" "$HOME/.config/gcloud"; do
  if [ -e "$d" ]; then
    mode="$(stat -c '%a' "$d" 2>/dev/null || true)"
    status_line INFO "secret-dir" "$d mode=$mode contents-not-printed"
  fi
done

section "summary"
if [ "$FAIL" -eq 1 ]; then
  status_line FAIL summary "required checks failed"
  exit 1
elif [ "$WARN" -eq 1 ]; then
  status_line WARN summary "warnings found; environment may still be usable"
  exit 0
else
  status_line OK summary "environment looks healthy"
  exit 0
fi
