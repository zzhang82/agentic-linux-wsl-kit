#!/usr/bin/env bash
# safe-yarn.sh - Interceptor for yarn to enforce Aegis security policy

SCRIPT_DIR="$(dirname "$(realpath "${BASH_SOURCE[0]}")")"
REAL_YARN="$(PATH="$(echo "$PATH" | tr ':' '\n' | grep -vE "^($HOME/\.local/bin|$SCRIPT_DIR)\$" | paste -sd ':' -)" command -v yarn)"
TRIGGER_SCRIPT="$SCRIPT_DIR/aegis-trigger.sh"

SUBCMD=""
skip_next=false
for arg in "$@"; do
  if [[ "$skip_next" == true ]]; then
    skip_next=false
    continue
  fi
  case "$arg" in
    --cwd|--dir|-C)
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

# In yarn, bare "yarn" or options without a non-install subcommand defaults to "yarn install"
if [[ -z "$SUBCMD" ]] || [[ "$SUBCMD" =~ ^(install|add|upgrade|up|remove|publish|run|exec|create)$ ]]; then
  target_cmd="${SUBCMD:-install}"
  echo "BLOCKED: raw yarn $target_cmd is not allowed in this environment." >&2
  echo "Routing to Aegis Trigger Layer..." >&2
  bash "$TRIGGER_SCRIPT" --event package-command --project "$PWD" -- "yarn $*"
  exit 1
fi

if [[ -z "$REAL_YARN" ]]; then
  echo "Error: Could not find real yarn binary." >&2
  exit 1
fi
exec "$REAL_YARN" "$@"
