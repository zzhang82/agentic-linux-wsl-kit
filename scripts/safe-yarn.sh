#!/usr/bin/env bash
# safe-yarn.sh - Interceptor for yarn to enforce security policy

REAL_YARN="$(command -v yarn)"
GUARD_SCRIPT="$(dirname "${BASH_SOURCE[0]}")/node-supply-chain-guard.sh"

case "$1" in
  add|install|upgrade)
    echo "BLOCKED: raw yarn $1 is not allowed in this environment." >&2
    echo "Please use the security guard to request this operation:" >&2
    echo "  $GUARD_SCRIPT --request \"yarn $*\"" >&2
    exit 1
    ;;
  *)
    exec "$REAL_YARN" "$@"
    ;;
esac
