#!/usr/bin/env bash
set -Eeuo pipefail

OUT_DIR="${1:-$HOME/wsl-migration-inventory-$(date +%Y%m%d-%H%M%S)}"
mkdir -p "$OUT_DIR"

umask 077
{
  echo "date=$(date -Is)"
  echo "user=$(id -un)"
  echo "kernel=$(uname -a)"
  [ -r /etc/os-release ] && cat /etc/os-release
} > "$OUT_DIR/system.txt"

env | sort | sed -E 's/(TOKEN|KEY|SECRET|PASSWORD)=.*/\1=<redacted>/Ig' > "$OUT_DIR/env-redacted.txt"
command -v dpkg >/dev/null 2>&1 && dpkg -l > "$OUT_DIR/dpkg-l.txt"
command -v apt-mark >/dev/null 2>&1 && apt-mark showmanual > "$OUT_DIR/apt-manual.txt"
if command -v npm >/dev/null 2>&1; then
  npm list -g --depth=0 > "$OUT_DIR/npm-global.txt" 2>&1 || true
fi
if command -v pipx >/dev/null 2>&1; then
  pipx list > "$OUT_DIR/pipx-list.txt" 2>&1 || true
fi

find "$HOME" -maxdepth 3 -type d -name .git -prune -print 2>/dev/null | sed 's#/.git$##' > "$OUT_DIR/git-repos.txt" || true
find "$HOME" -maxdepth 3 \( -name '*.pem' -o -name '*key*' -o -name '.env' -o -name 'credentials*' \) -printf '%m %s %p\n' 2>/dev/null > "$OUT_DIR/secret-looking-files-metadata.txt" || true

echo "Inventory written to $OUT_DIR"
echo "Secret-looking file CONTENTS were not printed. Review metadata before migration."
