#!/usr/bin/env bash
# safe-pnpm.sh - Interceptor for pnpm to enforce Aegis security policy

REAL_PNPM="$(command -v pnpm)"
TRIGGER_SCRIPT="$(dirname "${BASH_SOURCE[0]}")/aegis-trigger.sh"

case "$1" in
  install|update|add|exec|run|publish|token|owner|dist-tag)
    echo "BLOCKED: raw pnpm $1 is not allowed in this environment." >&2
    echo "Routing to Aegis Trigger Layer..." >&2
    bash "$TRIGGER_SCRIPT" --event package-command -- "pnpm $*"
    exit 1
    ;;
  *)
    exec "$REAL_PNPM" "$@"
    ;;
esac
