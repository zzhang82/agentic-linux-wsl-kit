#!/bin/bash
# aegis-trigger.sh: Central dispatcher for Aegis Skills events.
# Usage: bash scripts/aegis-trigger.sh --event <event-name> [args...]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AEGIS_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Default values
EVENT=""
PROJECT_DIR="."
DRY_RUN=false
STRICT=true

show_help() {
    echo "Aegis Trigger Dispatcher"
    echo ""
    echo "Usage: $0 --event <event> [--project <dir>] [--dry-run] [--non-strict] [-- <extra-args>]"
    echo ""
    echo "Events:"
    echo "  agent-start      - Preflight checks before starting an agent session"
    echo "  package-command  - Intercept and route package manager commands"
    echo "  git-pre-commit   - Lightweight checks before commit"
    echo "  git-pre-push     - Deeper checks and tests before push"
    echo "  git-post-merge   - Review changes after pull/merge (e.g. lockfiles)"
    echo "  daily / weekly   - Scheduled routine checks"
}

# Parse arguments
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --event) EVENT="$2"; shift ;;
        --project) PROJECT_DIR="$2"; shift ;;
        --dry-run) DRY_RUN=true ;;
        --non-strict) STRICT=false ;;
        --) shift; EXTRA_ARGS=("$@"); break ;;
        -h|--help) show_help; exit 0 ;;
        *) echo "Unknown parameter: $1"; exit 1 ;;
    esac
    shift
done

if [[ -z "$EVENT" ]]; then
    echo "Error: --event is required."
    show_help
    exit 1
fi

PROJECT_DIR="$(cd "$PROJECT_DIR" && pwd)"

log_event() {
    echo "[Aegis] Event: $EVENT | Project: $PROJECT_DIR"
}

run_cmd() {
    local cmd=("$@")
    if [[ "$DRY_RUN" == true ]]; then
        echo "[DRY-RUN] ${cmd[*]}"
    else
        "${cmd[@]}" || {
            local exit_code=$?
            if [[ "$STRICT" == true ]]; then
                exit $exit_code
            else
                echo "Warning: Command failed with exit code $exit_code, but continuing due to --non-strict"
            fi
        }
    fi
}

case "$EVENT" in
    agent-start)
        log_event
        echo "Running preflight security check..."
        run_cmd bash "$SCRIPT_DIR/wsl-security-check.sh" --preflight --project "$PROJECT_DIR"
        ;;

    package-command)
        log_event
        # EXTRA_ARGS contains the full command, e.g. "npm install axios"
        run_cmd bash "$SCRIPT_DIR/node-supply-chain-guard.sh" --request "${EXTRA_ARGS[*]}" --project "$PROJECT_DIR"
        ;;

    git-pre-commit)
        log_event
        echo "Running pre-commit secret scan (Gitleaks)..."
        if command -v gitleaks &> /dev/null; then
            run_cmd gitleaks protect --staged --verbose --redact
        else
            run_cmd bash "$SCRIPT_DIR/wsl-security-check.sh" --preflight --project "$PROJECT_DIR"
        fi
        ;;

    git-pre-push)
        log_event
        echo "Running pre-push health and security audit..."
        run_cmd bash "$SCRIPT_DIR/linux-doctor.sh"
        run_cmd bash "$SCRIPT_DIR/wsl-security-check.sh" --preflight --project "$PROJECT_DIR"
        if [[ -f "$PROJECT_DIR/tests/smoke.sh" ]]; then
            run_cmd bash "$PROJECT_DIR/tests/smoke.sh"
        fi
        ;;

    git-post-merge)
        log_event
        echo "Reviewing lockfile changes..."
        if git diff-tree -r --name-only HEAD@{1} HEAD | grep -qE "package-lock.json|pnpm-lock.yaml|yarn.lock|bun.lockb"; then
            echo "Lockfile change detected. Running security review..."
            run_cmd bash "$SCRIPT_DIR/node-supply-chain-guard.sh" --review-lockfile --project "$PROJECT_DIR"
        fi
        ;;

    daily|weekly|monthly)
        log_event
        echo "Running $EVENT routine..."
        run_cmd bash "$SCRIPT_DIR/wsl-security-check.sh" "--$EVENT" --project "$PROJECT_DIR"
        ;;

    *)
        echo "Error: Unsupported event '$EVENT'"
        exit 1
        ;;
esac

exit 0
