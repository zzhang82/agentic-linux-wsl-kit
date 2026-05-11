#!/usr/bin/env bash
set -Eeuo pipefail

APPLY=0
LANG_TOOLS=0

usage() {
  cat <<'EOF'
package-security-update.sh - safe package update workflow

Usage:
  scripts/package-security-update.sh [--preview] [--apply] [--language-tools]

Default is --preview. --apply is required before changing packages.
--language-tools updates opt-in CLIs such as uv, nvm LTS, pnpm, and common AI CLIs.
EOF
}

while [ "${1:-}" != "" ]; do
  case "$1" in
    --preview) APPLY=0; shift ;;
    --apply) APPLY=1; shift ;;
    --language-tools) LANG_TOOLS=1; shift ;;
    --help|-h) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage >&2; exit 2 ;;
  esac
done

if [ "$APPLY" -ne 1 ]; then
  echo "PREVIEW: would run: sudo apt-get update && sudo apt-get -y upgrade && sudo apt-get -y autoremove"
  [ "$LANG_TOOLS" -eq 1 ] && echo "PREVIEW: would update uv, nvm latest LTS, pnpm, and selected npm global AI CLIs"
  echo "Run with --apply after reviewing package-security-check.sh output."
  exit 0
fi

export DEBIAN_FRONTEND=noninteractive
sudo apt-get update
sudo apt-get -y upgrade
sudo apt-get -y autoremove

if [ "$LANG_TOOLS" -eq 1 ]; then
  if command -v uv >/dev/null 2>&1; then
    uv self update || true
  fi
  export NVM_DIR="$HOME/.nvm"
  if [ -s "$NVM_DIR/nvm.sh" ]; then
    # shellcheck source=/dev/null
    . "$NVM_DIR/nvm.sh"
    nvm install --lts
    nvm alias default 'lts/*'
    nvm use default
    corepack enable
    corepack prepare pnpm@latest --activate
    npm install -g opencode-ai @google/gemini-cli @anthropic-ai/claude-code task-master-ai
  fi
fi

"$(dirname "$0")/linux-doctor.sh"
