#!/usr/bin/env bash
# safe-yarn.sh - Interceptor for yarn to enforce Aegis security policy

REAL_YARN="$(PATH="$(echo "$PATH" | tr ':' '\n' | grep -vE "$HOME/.local/bin|$(dirname "${BASH_SOURCE[0]}")" | paste -sd ':' -)" command -v yarn)"
TRIGGER_SCRIPT="$(dirname "${BASH_SOURCE[0]}")/aegis-trigger.sh"

case "$1" in
  install|add|upgrade|remove|publish|run)
    echo "BLOCKED: raw yarn $1 is not allowed in this environment." >&2
    echo "Routing to Aegis Trigger Layer..." >&2
    bash "$TRIGGER_SCRIPT" --event package-command --project "$PWD" -- "yarn $*"
    exit 1
    ;;
  *)
    if [[ -z "$REAL_YARN" ]]; then
      echo "Error: Could not find real yarn binary." >&2
      exit 1
    fi
    exec "$REAL_YARN" "$@"
    ;;
esac
