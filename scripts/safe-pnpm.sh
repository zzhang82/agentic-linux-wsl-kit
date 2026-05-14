#!/usr/bin/env bash
# safe-pnpm.sh - Interceptor for pnpm to enforce Aegis security policy

REAL_PNPM="$(PATH="$(echo "$PATH" | tr ':' '\n' | grep -vE "$HOME/.local/bin|$(dirname "${BASH_SOURCE[0]}")" | paste -sd ':' -)" command -v pnpm)"
TRIGGER_SCRIPT="$(dirname "${BASH_SOURCE[0]}")/aegis-trigger.sh"

case "$1" in
  install|update|add|exec|run|publish|token|owner|dist-tag)
    echo "BLOCKED: raw pnpm $1 is not allowed in this environment." >&2
    echo "Routing to Aegis Trigger Layer..." >&2
    bash "$TRIGGER_SCRIPT" --event package-command --project "$PWD" -- "pnpm $*"
    exit 1
    ;;
  *)
    if [[ -z "$REAL_PNPM" ]]; then
      echo "Error: Could not find real pnpm binary." >&2
      exit 1
    fi
    exec "$REAL_PNPM" "$@"
    ;;
esac
