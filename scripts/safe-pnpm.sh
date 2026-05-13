#!/usr/bin/env bash
# safe-pnpm.sh - Interceptor for pnpm to enforce security policy

REAL_PNPM="$(command -v pnpm)"
GUARD_SCRIPT="$(dirname "${BASH_SOURCE[0]}")/node-supply-chain-guard.sh"

case "$1" in
  add|update|install|i|up|dlx)
    echo "BLOCKED: raw pnpm $1 is not allowed in this environment." >&2
    echo "Please use the security guard to request this operation:" >&2
    echo "  $GUARD_SCRIPT --request \"pnpm $*\"" >&2
    exit 1
    ;;
  *)
    exec "$REAL_PNPM" "$@"
    ;;
esac
