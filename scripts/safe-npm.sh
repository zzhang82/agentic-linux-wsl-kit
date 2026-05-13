#!/usr/bin/env bash
# safe-npm.sh - Interceptor for npm to enforce security policy

REAL_NPM="$(command -v npm)"
GUARD_SCRIPT="$(dirname "${BASH_SOURCE[0]}")/node-supply-chain-guard.sh"

case "$1" in
  install|update|add|exec|run|publish|token|owner|dist-tag)
    echo "BLOCKED: raw npm $1 is not allowed in this environment." >&2
    echo "Please use the security guard to request this operation:" >&2
    echo "  $GUARD_SCRIPT --request \"npm $*\"" >&2
    exit 1
    ;;
  *)
    exec "$REAL_NPM" "$@"
    ;;
esac
