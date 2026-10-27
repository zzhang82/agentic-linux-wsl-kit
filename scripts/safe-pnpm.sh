#!/usr/bin/env bash
# safe-pnpm.sh - Interceptor for pnpm to enforce Aegis security policy

SCRIPT_DIR="$(dirname "$(realpath "${BASH_SOURCE[0]}")")"
REAL_PNPM="$(PATH="$(echo "$PATH" | tr ':' '\n' | grep -vE "^($HOME/\.local/bin|$SCRIPT_DIR)\$" | paste -sd ':' -)" command -v pnpm)"
TRIGGER_SCRIPT="$SCRIPT_DIR/aegis-trigger.sh"

SUBCMD=""
skip_next=false
for arg in "$@"; do
  if [[ "$skip_next" == true ]]; then
    skip_next=false
    continue
  fi
  case "$arg" in
    --prefix|--cwd|--dir|-C|--filter|--registry)
      skip_next=true
      continue
      ;;
    --prefix=*|--cwd=*|--dir=*|--filter=*|--registry=*)
      continue
      ;;
    -w|--workspace-root|-r|--recursive|-g|--global|-*)
      continue
      ;;
    *)
      SUBCMD="$arg"
      break
      ;;
  esac
done

case "$SUBCMD" in
  install|i|ci|update|up|upgrade|add|exec|run|publish|token|owner|dist-tag|rebuild|dlx)
    echo "BLOCKED: raw pnpm $SUBCMD is not allowed in this environment." >&2
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
