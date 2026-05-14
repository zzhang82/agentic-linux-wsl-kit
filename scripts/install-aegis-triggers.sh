#!/bin/bash
# install-aegis-triggers.sh: Opt-in setup for Aegis safety harness.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AEGIS_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
BIN_DIR="$HOME/.local/bin"

show_help() {
    echo "Aegis Trigger Installer"
    echo ""
    echo "Usage: $0 [options]"
    echo ""
    echo "Options:"
    echo "  --wrappers     - Install package manager wrappers (npm, pnpm, etc.) to $BIN_DIR"
    echo "  --git-hooks    - Configure current repo to use Aegis git hooks"
    echo "  --systemd-user - Install systemd user timers for daily/weekly checks"
    echo "  --all          - Install all of the above"
    echo "  --dry-run      - Show what would be done"
}

INSTALL_WRAPPERS=false
INSTALL_GIT_HOOKS=false
INSTALL_SYSTEMD=false
DRY_RUN=false

while [[ "$#" -gt 0 ]]; do
    case $1 in
        --wrappers) INSTALL_WRAPPERS=true ;;
        --git-hooks) INSTALL_GIT_HOOKS=true ;;
        --systemd-user) INSTALL_SYSTEMD=true ;;
        --all)
            INSTALL_WRAPPERS=true
            INSTALL_GIT_HOOKS=true
            INSTALL_SYSTEMD=true
            ;;
        --dry-run) DRY_RUN=true ;;
        -h|--help) show_help; exit 0 ;;
        *) echo "Unknown parameter: $1"; exit 1 ;;
    esac
    shift
done

if [[ "$INSTALL_WRAPPERS" == false && "$INSTALL_GIT_HOOKS" == false && "$INSTALL_SYSTEMD" == false ]]; then
    echo "Error: No install options selected."
    show_help
    exit 1
fi

# 1. Wrappers
if [[ "$INSTALL_WRAPPERS" == true ]]; then
    echo "Installing command wrappers to $BIN_DIR..."
    if [[ "$DRY_RUN" == false ]]; then
        mkdir -p "$BIN_DIR"
        ln -sf "$SCRIPT_DIR/safe-npm.sh" "$BIN_DIR/npm"
        ln -sf "$SCRIPT_DIR/safe-npx.sh" "$BIN_DIR/npx"
        ln -sf "$SCRIPT_DIR/safe-pnpm.sh" "$BIN_DIR/pnpm"
        ln -sf "$SCRIPT_DIR/safe-yarn.sh" "$BIN_DIR/yarn"
        ln -sf "$SCRIPT_DIR/safe-bun.sh" "$BIN_DIR/bun"
        echo "OK: Wrappers installed. Ensure $BIN_DIR is in your PATH."
    else
        echo "[DRY-RUN] Would link safe-*.sh to $BIN_DIR"
    fi
fi

# 2. Git Hooks
if [[ "$INSTALL_GIT_HOOKS" == true ]]; then
    if git rev-parse --is-inside-work-tree &>/dev/null; then
        echo "Configuring git hooks for current repository..."
        if [[ "$DRY_RUN" == false ]]; then
            git config core.hooksPath .githooks
            echo "OK: git hooks configured to use .githooks/"
        else
            echo "[DRY-RUN] Would run: git config core.hooksPath .githooks"
        fi
    else
        echo "Warning: Not a git repository. Skipping git hooks."
    fi
fi

# 3. Systemd (Placeholder for now, just creating the directory and files)
if [[ "$INSTALL_SYSTEMD" == true ]]; then
    echo "Setting up systemd user timers..."
    SYSTEMD_USER_DIR="$HOME/.config/systemd/user"
    if [[ "$DRY_RUN" == false ]]; then
        mkdir -p "$SYSTEMD_USER_DIR"
        # We will create the service/timer files in a future step or use templates
        echo "OK: systemd user directory prepared. (Timer templates pending in MVP6b)"
    else
        echo "[DRY-RUN] Would create $SYSTEMD_USER_DIR"
    fi
fi

echo "Aegis installation complete."
