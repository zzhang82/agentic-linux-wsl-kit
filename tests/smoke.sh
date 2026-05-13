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
bash -n scripts/node-supply-chain-guard.sh
echo "ok scripts/node-supply-chain-guard.sh"
bash -n scripts/safe-npm.sh
echo "ok scripts/safe-npm.sh"
bash scripts/wsl-security-check.sh --list-tools >/tmp/agentic-linux-wsl-kit-tools.txt
echo "ok scripts/wsl-security-check.sh --list-tools"
python3 -m py_compile scripts/wsl-security-summarize.py
echo "ok scripts/wsl-security-summarize.py"

echo "== security docs present =="
test -s docs/security-routine-sop.md
test -s docs/tool-policy.md
test -s docs/agent-active-defense.md
test -s docs/npm-supply-chain-policy.md
echo "ok docs"

echo "== non-destructive script runs =="
bash scripts/linux-doctor.sh >/tmp/agentic-linux-wsl-kit-doctor.txt
bash scripts/linux-doctor.sh --format json >/tmp/agentic-linux-wsl-kit-doctor.jsonl
bash scripts/package-security-update.sh --preview >/tmp/agentic-linux-wsl-kit-update-preview.txt
bash scripts/wsl-security-check.sh --daily >/tmp/agentic-linux-wsl-kit-security-daily.txt
bash scripts/node-supply-chain-guard.sh --preinstall >/tmp/agentic-linux-wsl-kit-guard-pre.txt
bash scripts/node-supply-chain-guard.sh --request "npm install axios" >/tmp/agentic-linux-wsl-kit-guard-req.txt

echo "== secret scan sanity =="
if grep -RInE '(apiKey|BEGIN (RSA|OPENSSH|PRIVATE) KEY|password\s*=|token\s*=)' README.md docs scripts skills 2>/dev/null; then
  echo "Potential secret-like text found. Review output above."
  exit 1
fi

echo "PASS smoke tests"
