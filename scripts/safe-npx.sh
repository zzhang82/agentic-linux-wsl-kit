#!/usr/bin/env bash
# safe-npx.sh - Interceptor for npx to enforce Aegis security policy

REAL_NPX="$(PATH="$(echo "$PATH" | tr ':' '\n' | grep -vE "$HOME/.local/bin|$(dirname "${BASH_SOURCE[0]}")" | paste -sd ':' -)" command -v npx)"
TRIGGER_SCRIPT="$(dirname "${BASH_SOURCE[0]}")/aegis-trigger.sh"

echo "BLOCKED: raw npx is not allowed in this environment." >&2
echo "Routing to Aegis Trigger Layer..." >&2
bash "$TRIGGER_SCRIPT" --event package-command --project "$PWD" -- "npx $*"
exit 1
