#!/usr/bin/env bash
# node-supply-chain-guard.sh - Active defense against npm/pnpm supply chain attacks
set -Eeuo pipefail

VERSION="0.1.0"
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_PATH="${PROJECT_PATH:-$PWD}"

usage() {
  cat <<EOF
node-supply-chain-guard.sh v$VERSION

Usage:
  $0 [mode] [options]

Modes:
  --preinstall       Check project config, registry, and lockfile state
  --review-lockfile  Review changes in lockfile for suspicious entries
  --request "CMD"    Interface for requesting a package operation
  --postinstall-scan Run security scans on the newly installed node_modules
  --list-scripts     Extract and list lifecycle scripts from package.json
  --execute-approved "TYPE"  Execute a pre-approved safe command (e.g. npm-ci, pnpm-install)

Options:
  --project PATH     Specific project directory (default: current)
  --help, -h         Show this help
EOF
}

MODE=""
REQUEST_CMD=""

while [ "${1:-}" != "" ]; do
  case "$1" in
    --preinstall|--review-lockfile|--postinstall-scan|--list-scripts) MODE="${1#--}"; shift ;;
    --request) MODE="request"; REQUEST_CMD="$2"; shift 2 ;;
    --execute-approved) MODE="execute-approved"; REQUEST_CMD="$2"; shift 2 ;;
    --project) PROJECT_PATH="$2"; shift 2 ;;
    --help|-h) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage >&2; exit 2 ;;
  esac
done

if [ -z "$MODE" ]; then
  echo "Error: mode is required." >&2
  usage >&2
  exit 2
fi

have() { command -v "$1" >/dev/null 2>&1; }

# Enforcement Logic
case "$MODE" in
  preinstall)
    echo "== Pre-install Check =="
    if have npm; then
      reg="$(npm config get registry)"
      echo "INFO npm registry: $reg"
      if [[ "$reg" != "https://registry.npmjs.org/" ]]; then
        echo "WARN non-standard npm registry detected"
      fi
    fi
    if [ -f "$PROJECT_PATH/package-lock.json" ] || [ -f "$PROJECT_PATH/pnpm-lock.yaml" ]; then
      echo "OK lockfile present"
    else
      echo "WARN no lockfile found; install will be non-deterministic"
    fi
    ;;

  list-scripts)
    echo "== Lifecycle Scripts Review =="
    if [ -f "$PROJECT_PATH/package.json" ] && have jq; then
      jq -r '.scripts | to_entries[] | select(.key | (contains("pre") or contains("post") or . == "install" or . == "prepare")) | "\(.key): \(.value)"' "$PROJECT_PATH/package.json" || echo "INFO no lifecycle scripts found"
    else
      echo "INFO package.json missing or jq not installed"
    fi
    ;;

  request)
    echo "== Package Operation Request =="
    echo "REQUESTED: $REQUEST_CMD"
    
    # Simple risk assessment
    RISK="LOW"
    if [[ "$REQUEST_CMD" == *"install"* ]] || [[ "$REQUEST_CMD" == *"add"* ]]; then
      RISK="MEDIUM"
    fi
    if [[ "$REQUEST_CMD" != *"--ignore-scripts"* ]]; then
      RISK="HIGH"
    fi
    
    echo "RISK LEVEL: $RISK"
    echo "REASONING: raw install commands without --ignore-scripts are high-risk."
    echo "RECOMMENDATION: Use 'npm ci --ignore-scripts' or 'pnpm install --frozen-lockfile --ignore-scripts'."
    echo ""
    echo "PROPOSED SAFE EXECUTION:"
    if [[ "$REQUEST_CMD" == *"npm"* ]]; then
      echo "  $0 --execute-approved npm-ci --project \"$PROJECT_PATH\""
    elif [[ "$REQUEST_CMD" == *"pnpm"* ]]; then
      echo "  $0 --execute-approved pnpm-install --project \"$PROJECT_PATH\""
    fi
    ;;

  execute-approved)
    echo "== Executing Approved Safe Command =="
    TMP_HOME="$(mktemp -d)"
    echo "INFO using isolated HOME: $TMP_HOME"
    
    # Strictly defined path + current node bin
    NODE_BIN="$(dirname "$(command -v node 2>/dev/null || echo "/usr/bin/node")")"
    SAFE_PATH="$NODE_BIN:/usr/local/bin:/usr/bin:/bin"
    
    case "$REQUEST_CMD" in
      npm-ci)
        echo "INFO running npm ci --ignore-scripts"
        env -i \
          HOME="$TMP_HOME" \
          PATH="$SAFE_PATH" \
          npm_config_userconfig="$TMP_HOME/.npmrc" \
          npm_config_cache="$TMP_HOME/.npm-cache" \
          npm ci --ignore-scripts
        ;;
      pnpm-install)
        echo "INFO running pnpm install --frozen-lockfile --ignore-scripts"
        env -i \
          HOME="$TMP_HOME" \
          PATH="$SAFE_PATH" \
          PNPM_HOME="$TMP_HOME/.pnpm" \
          npm_config_userconfig="$TMP_HOME/.npmrc" \
          pnpm install --frozen-lockfile --ignore-scripts
        ;;
      *)
        echo "ERROR unknown approved command type: $REQUEST_CMD"
        exit 1
        ;;
    esac
    rm -rf "$TMP_HOME"
    ;;

  postinstall-scan)
    echo "== Post-install Security Scan =="
    if [ -d "$PROJECT_PATH/node_modules" ]; then
      if have gitleaks; then
        echo "INFO running gitleaks on node_modules"
        gitleaks detect --source "$PROJECT_PATH/node_modules" --no-banner --redact || true
      fi
      if have trivy; then
        echo "INFO running trivy fs on node_modules"
        trivy fs "$PROJECT_PATH/node_modules" --scanners vuln,secret --severity HIGH,CRITICAL || true
      fi
    else
      echo "ERROR node_modules not found"
    fi
    ;;

  review-lockfile)
    echo "== Lockfile Review =="
    # This is a placeholder for a more complex diffing logic
    if have git && [ -d "$PROJECT_PATH/.git" ]; then
      git -C "$PROJECT_PATH" diff HEAD -- package-lock.json pnpm-lock.yaml 2>/dev/null || echo "INFO no lockfile changes staged"
    else
      echo "INFO not a git repo or no staged changes"
    fi
    ;;
esac
