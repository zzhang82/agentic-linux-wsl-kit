#!/usr/bin/env bash
# safe-npx.sh - Interceptor for npx to enforce security policy

REAL_NPX="$(command -v npx)"
GUARD_SCRIPT="$(dirname "${BASH_SOURCE[0]}")/node-supply-chain-guard.sh"

echo "BLOCKED: raw npx is not allowed in this environment." >&2
echo "Please use the security guard to request this operation:" >&2
echo "  $GUARD_SCRIPT --request \"npx $*\"" >&2
exit 1
