#!/usr/bin/env bash
# safe-npm.sh - Interceptor for npm to enforce Aegis security policy

# Prevent wrapper recursion by excluding ~/.local/bin from the search path
REAL_NPM="$(PATH="$(echo "$PATH" | tr ':' '\n' | grep -vE "$HOME/.local/bin|$(dirname "${BASH_SOURCE[0]}")" | paste -sd ':' -)" command -v npm)"
TRIGGER_SCRIPT="$(dirname "${BASH_SOURCE[0]}")/aegis-trigger.sh"

case "$1" in
  install|update|add|exec|run|publish|token|owner|dist-tag)
    echo "BLOCKED: raw npm $1 is not allowed in this environment." >&2
    echo "Routing to Aegis Trigger Layer..." >&2
    bash "$TRIGGER_SCRIPT" --event package-command --project "$PWD" -- "npm $*"
    exit 1
    ;;
  *)
    if [[ -z "$REAL_NPM" ]]; then
      echo "Error: Could not find real npm binary." >&2
      exit 1
    fi
    exec "$REAL_NPM" "$@"
    ;;
esac
