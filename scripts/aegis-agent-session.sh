#!/bin/bash
# aegis-agent-session.sh: Launch an agent or shell with Aegis safety harness active.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AEGIS_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
BIN_DIR="$HOME/.local/bin"

PROJECT_DIR="."

show_help() {
    echo "Aegis Agent Session Launcher"
    echo ""
    echo "Usage: $0 [--project <dir>] -- <command> [args...]"
    echo ""
    echo "Example:"
    echo "  $0 --project . -- opencode"
    echo "  $0 --project . -- bash"
}

while [[ "$#" -gt 0 ]]; do
    case $1 in
        --project) PROJECT_DIR="$2"; shift ;;
        --) shift; AGENT_COMMAND=("$@"); break ;;
        -h|--help) show_help; exit 0 ;;
        *) echo "Unknown parameter: $1"; exit 1 ;;
    esac
    shift
done

if [[ -z "${AGENT_COMMAND[*]}" ]]; then
    echo "Error: No agent command provided."
    show_help
    exit 1
fi

PROJECT_DIR="$(cd "$PROJECT_DIR" && pwd)"

# 1. Trigger agent-start event
bash "$SCRIPT_DIR/aegis-trigger.sh" --event agent-start --project "$PROJECT_DIR"

# 2. Prepare safe environment
echo "[Aegis] Preparing safe environment for: ${AGENT_COMMAND[*]}"

# Inject our wrappers into the front of the PATH
export PATH="$SCRIPT_DIR:$PATH"
if [[ -d "$BIN_DIR" ]]; then
    export PATH="$BIN_DIR:$PATH"
fi

# Ensure Aegis scripts are available
export AEGIS_PATH="$SCRIPT_DIR"

# 3. Launch agent
echo "[Aegis] Session start."
echo "--------------------------------------------------"
exec "${AGENT_COMMAND[@]}"
