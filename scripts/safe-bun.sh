#!/usr/bin/env bash
# safe-bun.sh - Interceptor for bun to enforce security policy

REAL_BUN="$(command -v bun)"
GUARD_SCRIPT="$(dirname "${BASH_SOURCE[0]}")/node-supply-chain-guard.sh"

case "$1" in
  add|install|update|upgrade|x|run)
    echo "BLOCKED: raw bun $1 is not allowed in this environment." >&2
    echo "Please use the security guard to request this operation:" >&2
    echo "  $GUARD_SCRIPT --request \"bun $*\"" >&2
    exit 1
    ;;
  *)
    exec "$REAL_BUN" "$@"
    ;;
esac
