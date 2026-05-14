#!/usr/bin/env bash
# safe-npm.sh - Interceptor for npm to enforce Aegis security policy

REAL_NPM="$(command -v npm)"
TRIGGER_SCRIPT="$(dirname "${BASH_SOURCE[0]}")/aegis-trigger.sh"

case "$1" in
  install|update|add|exec|run|publish|token|owner|dist-tag)
    echo "BLOCKED: raw npm $1 is not allowed in this environment." >&2
    echo "Routing to Aegis Trigger Layer..." >&2
    bash "$TRIGGER_SCRIPT" --event package-command -- "npm $*"
    exit 1
    ;;
  *)
    exec "$REAL_NPM" "$@"
    ;;
esac
