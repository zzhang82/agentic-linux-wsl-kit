#!/usr/bin/env bash
set -Eeuo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

echo "== shell syntax =="
for f in scripts/*.sh; do
  bash -n "$f"
  echo "ok $f"
done

echo "== powershell scripts present =="
for f in scripts/*.ps1; do
  test -s "$f"
  echo "ok $f"
done

echo "== skill metadata =="
for f in skills/*/SKILL.md; do
  grep -q '^---$' "$f"
  grep -q '^name:' "$f"
  grep -q '^description:' "$f"
  grep -q '^version:' "$f"
  echo "ok $f"
done

echo "== security routine scripts =="
bash -n scripts/wsl-security-check.sh
echo "ok scripts/wsl-security-check.sh"
python3 -m py_compile scripts/wsl-security-summarize.py
echo "ok scripts/wsl-security-summarize.py"

echo "== security docs present =="
test -s docs/security-routine-sop.md
test -s docs/tool-policy.md
echo "ok docs"

echo "== non-destructive script runs =="
bash scripts/linux-doctor.sh >/tmp/agentic-linux-wsl-kit-doctor.txt
bash scripts/linux-doctor.sh --format json >/tmp/agentic-linux-wsl-kit-doctor.jsonl
bash scripts/package-security-update.sh --preview >/tmp/agentic-linux-wsl-kit-update-preview.txt
bash scripts/wsl-security-check.sh --daily >/tmp/agentic-linux-wsl-kit-security-daily.txt

echo "== secret scan sanity =="
if grep -RInE '(apiKey|BEGIN (RSA|OPENSSH|PRIVATE) KEY|password\s*=|token\s*=)' README.md docs scripts skills 2>/dev/null; then
  echo "Potential secret-like text found. Review output above."
  exit 1
fi

echo "PASS smoke tests"
