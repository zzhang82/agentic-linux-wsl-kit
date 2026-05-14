#!/usr/bin/env bash
# safe-yarn.sh - Interceptor for yarn to enforce Aegis security policy

REAL_YARN="$(command -v yarn)"
TRIGGER_SCRIPT="$(dirname "${BASH_SOURCE[0]}")/aegis-trigger.sh"

case "$1" in
  install|add|upgrade|remove|publish|run)
    echo "BLOCKED: raw yarn $1 is not allowed in this environment." >&2
    echo "Routing to Aegis Trigger Layer..." >&2
    bash "$TRIGGER_SCRIPT" --event package-command -- "yarn $*"
    exit 1
    ;;
  *)
    exec "$REAL_YARN" "$@"
    ;;
esac
