#!/usr/bin/env bash
# safe-bun.sh - Interceptor for bun to enforce Aegis security policy

REAL_BUN="$(PATH="$(echo "$PATH" | tr ':' '\n' | grep -vE "$HOME/.local/bin|$(dirname "${BASH_SOURCE[0]}")" | paste -sd ':' -)" command -v bun)"
TRIGGER_SCRIPT="$(dirname "${BASH_SOURCE[0]}")/aegis-trigger.sh"

case "$1" in
  install|add|update|remove|run|x|publish)
    echo "BLOCKED: raw bun $1 is not allowed in this environment." >&2
    echo "Routing to Aegis Trigger Layer..." >&2
    bash "$TRIGGER_SCRIPT" --event package-command --project "$PWD" -- "bun $*"
    exit 1
    ;;
  *)
    if [[ -z "$REAL_BUN" ]]; then
      echo "Error: Could not find real bun binary." >&2
      exit 1
    fi
    exec "$REAL_BUN" "$@"
    ;;
esac
