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
    echo "PROPOSED SAFE COMMAND:"
    if [[ "$REQUEST_CMD" == *"npm"* ]]; then
      echo "env -i PATH=\"$PATH\" HOME=\"$HOME\" npm ci --ignore-scripts"
    elif [[ "$REQUEST_CMD" == *"pnpm"* ]]; then
      echo "env -i PATH=\"$PATH\" HOME=\"$HOME\" pnpm install --frozen-lockfile --ignore-scripts"
    fi
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
