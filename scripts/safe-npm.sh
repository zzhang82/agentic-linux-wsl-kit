#!/usr/bin/env bash
# safe-npm.sh - Interceptor for npm to enforce Aegis security policy

SCRIPT_DIR="$(dirname "$(realpath "${BASH_SOURCE[0]}")")"
REAL_NPM="$(PATH="$(echo "$PATH" | tr ':' '\n' | grep -vE "^($HOME/\.local/bin|$SCRIPT_DIR)\$" | paste -sd ':' -)" command -v npm)"
TRIGGER_SCRIPT="$SCRIPT_DIR/aegis-trigger.sh"

SUBCMD=""
skip_next=false
for arg in "$@"; do
  if [[ "$skip_next" == true ]]; then
    skip_next=false
    continue
  fi
  case "$arg" in
    --prefix|--cwd|--dir|-C|--workspace|-w|--registry|--cache|--userconfig)
      skip_next=true
      continue
      ;;
    --prefix=*|--cwd=*|--dir=*|--workspace=*|--registry=*|--cache=*|--userconfig=*)
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
  install|i|ci|update|up|upgrade|add|exec|run|run-script|publish|token|owner|dist-tag|rebuild)
    echo "BLOCKED: raw npm $SUBCMD is not allowed in this environment." >&2
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
