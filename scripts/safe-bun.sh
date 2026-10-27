#!/usr/bin/env bash
# safe-bun.sh - Interceptor for bun to enforce Aegis security policy

SCRIPT_DIR="$(dirname "$(realpath "${BASH_SOURCE[0]}")")"
REAL_BUN="$(PATH="$(echo "$PATH" | tr ':' '\n' | grep -vE "^($HOME/\.local/bin|$SCRIPT_DIR)\$" | paste -sd ':' -)" command -v bun)"
TRIGGER_SCRIPT="$SCRIPT_DIR/aegis-trigger.sh"

SUBCMD=""
skip_next=false
for arg in "$@"; do
  if [[ "$skip_next" == true ]]; then
    skip_next=false
    continue
  fi
  case "$arg" in
    --cwd|--dir|-c)
      skip_next=true
      continue
      ;;
    --cwd=*|--dir=*)
      continue
      ;;
    -*)
      continue
      ;;
    *)
      SUBCMD="$arg"
      break
      ;;
  esac
done

case "$SUBCMD" in
  install|i|add|a|update|up|remove|rm|run|x|publish)
    echo "BLOCKED: raw bun $SUBCMD is not allowed in this environment." >&2
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
