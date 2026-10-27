#!/usr/bin/env bash
# safe-npx.sh - Interceptor for npx to enforce Aegis security policy

SCRIPT_DIR="$(dirname "$(realpath "${BASH_SOURCE[0]}")")"
REAL_NPX="$(PATH="$(echo "$PATH" | tr ':' '\n' | grep -vE "^($HOME/\.local/bin|$SCRIPT_DIR)\$" | paste -sd ':' -)" command -v npx)"
TRIGGER_SCRIPT="$SCRIPT_DIR/aegis-trigger.sh"

echo "BLOCKED: raw npx is not allowed in this environment." >&2
echo "Routing to Aegis Trigger Layer..." >&2
bash "$TRIGGER_SCRIPT" --event package-command --project "$PWD" -- "npx $*"
exit 1
