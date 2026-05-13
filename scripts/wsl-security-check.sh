#!/usr/bin/env bash
# wsl-security-check.sh - read-only WSL/Linux security routine driver
set -Eeuo pipefail

VERSION="0.1.0"
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STATE_DIR="$HOME/.local/state/wsl-security"

usage() {
  cat <<EOF
wsl-security-check.sh v$VERSION

Usage:
  $0 [mode] [options]

Modes:
  --daily        Fast, local, no sudo, no network
  --weekly       Network allowed, includes Lynis/Gitleaks/Trivy
  --monthly      Deep scan, SBOM/Grype/TruffleHog/Docker
  --preflight    Fast check before coding-agent work
  --list-tools   Report status of integrated scanners without running audit

Options:
  --project PATH   Specific project directory to scan (default: current or ~/projects)
  --help, -h       Show this help
EOF
}

MODE=""
PROJECT_PATH="${PROJECT_PATH:-$PWD}"

while [ "${1:-}" != "" ]; do
  case "$1" in
    --daily|--weekly|--monthly|--preflight|--list-tools|--doctor-tools)
      if [ "$1" = "--doctor-tools" ]; then MODE="list-tools"; else MODE="${1#--}"; fi
      shift ;;
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

# Common helpers
have() { command -v "$1" >/dev/null 2>&1; }

if [ "$MODE" = "list-tools" ]; then
  echo "== security tools status =="
  for t in lynis gitleaks trivy syft grype trufflehog docker python3; do
    if have "$t"; then
      printf 'OK   %-12s %s\n' "$t" "$(command -v "$t")"
    else
      printf 'MISS %-12s\n' "$t"
    fi
  done
  exit 0
fi

# Setup run directory
TIMESTAMP="$(date -u +%Y%m%dT%H%M%SZ)"
RUN_DIR="$STATE_DIR/${MODE}-${TIMESTAMP}"
mkdir -p "$RUN_DIR"

echo "INFO starting $MODE security check"
echo "INFO run directory: $RUN_DIR"

# Export variables for Python manifest creator
export MODE TIMESTAMP_UTC="$(date -u +%Y-%m-%dT%H:%M:%SZ)" PROJECT_PATH RUN_DIR VERSION

# Create manifest safely using Python
python3 -c '
import json, sys, os, subprocess, shutil
def get_ver(cmd, args):
    if not shutil.which(cmd): return "missing"
    try:
        return subprocess.run([cmd] + args, capture_output=True, text=True, timeout=2).stdout.splitlines()[0].strip()
    except:
        return "error"

manifest = {
    "mode": os.environ.get("MODE"),
    "timestamp_utc": os.environ.get("TIMESTAMP_UTC"),
    "project_path": os.environ.get("PROJECT_PATH"),
    "tool_versions": {
        "driver": os.environ.get("VERSION"),
        "lynis": get_ver("lynis", ["show", "version"]),
        "gitleaks": get_ver("gitleaks", ["version"]),
        "trivy": get_ver("trivy", ["--version"]),
        "syft": get_ver("syft", ["--version"]),
        "grype": get_ver("grype", ["version"]),
        "trufflehog": get_ver("trufflehog", ["--version"]),
        "docker": get_ver("docker", ["--version"]),
        "python3": get_ver("python3", ["--version"])
    }
}
with open(os.path.join(os.environ.get("RUN_DIR"), "manifest.json"), "w") as f:
    json.dump(manifest, f, indent=2)
'

# 1. Base diagnostics (linux-doctor)
echo "INFO running linux-doctor"
bash "$BASE_DIR/scripts/linux-doctor.sh" --format json > "$RUN_DIR/linux-doctor.ndjson" 2>&1 || true

# 2. Package security check
echo "INFO running package-security-check"
case "$MODE" in
  daily|preflight)
    bash "$BASE_DIR/scripts/package-security-check.sh" --no-network --format json > "$RUN_DIR/package-check.ndjson" 2>&1 || true
    ;;
  *)
    bash "$BASE_DIR/scripts/package-security-check.sh" --format json > "$RUN_DIR/package-check.ndjson" 2>&1 || true
    ;;
esac

# 3. Secret directory metadata
echo "INFO checking secret directory metadata"
find "$HOME/.ssh" "$HOME/.gnupg" "$HOME/.aws" "$HOME/.config/gcloud" \
  -maxdepth 1 -type d -exec stat -c '%n mode=%a owner=%U group=%G' {} \; \
  > "$RUN_DIR/secret-dir-metadata.txt" 2>/dev/null || true

# 4. Mode-specific scanners
if [ "$MODE" = "weekly" ] || [ "$MODE" = "monthly" ]; then
  if have lynis; then
    echo "INFO running lynis audit"
    if sudo -n true 2>/dev/null; then
      # shellcheck disable=SC2024
      sudo lynis audit system --quick --no-colors > "$RUN_DIR/lynis.txt" 2>&1 || true
    else
      echo "WARN lynis skipped: sudo without prompt is unavailable" > "$RUN_DIR/lynis.txt"
    fi
  fi

  if have gitleaks; then
    echo "INFO running gitleaks"
    if [ -d "$PROJECT_PATH/.git" ]; then
      gitleaks detect --source "$PROJECT_PATH" --no-banner --redact --report-format json --report-path "$RUN_DIR/gitleaks-project.json" > "$RUN_DIR/gitleaks-project.txt" 2>&1 || true
    fi
  fi

  if have trivy; then
    echo "INFO running trivy fs"
    trivy fs --scanners vuln,misconfig,secret --skip-dirs "$HOME/.cache" --format json --output "$RUN_DIR/trivy-fs.json" "$PROJECT_PATH" > "$RUN_DIR/trivy-fs.txt" 2>&1 || true
  fi
fi

if [ "$MODE" = "monthly" ]; then
  if have trufflehog; then
    echo "INFO running trufflehog"
    # Prefer JSON output for safer parsing and redaction
    trufflehog filesystem "$PROJECT_PATH" --only-verified --json > "$RUN_DIR/trufflehog.json" 2> "$RUN_DIR/trufflehog-error.txt" || true
  fi

  if have syft && have grype; then
    echo "INFO generating SBOM and scanning"
    syft "$PROJECT_PATH" -o cyclonedx-json="$RUN_DIR/sbom.cdx.json" >/dev/null 2>&1 || true
    if [ -f "$RUN_DIR/sbom.cdx.json" ]; then
      grype "sbom:$RUN_DIR/sbom.cdx.json" -o json > "$RUN_DIR/grype.json" 2> "$RUN_DIR/grype.txt" || true
    fi
  fi

  if have docker && docker info >/dev/null 2>&1; then
    echo "Docker reachable. Run Docker Bench manually with sudo if approved." > "$RUN_DIR/docker-next-step.txt"
  fi
fi

if [ "$MODE" = "preflight" ]; then
  if [ -d "$PROJECT_PATH/.git" ]; then
    echo "INFO running git status"
    git -C "$PROJECT_PATH" status --short --branch > "$RUN_DIR/git-status.txt" 2>&1 || true
    if have gitleaks; then
      echo "INFO running gitleaks preflight"
      gitleaks detect --source "$PROJECT_PATH" --no-banner --redact --report-format json --report-path "$RUN_DIR/gitleaks-preflight.json" > "$RUN_DIR/gitleaks-preflight.txt" 2>&1 || true
    fi
  fi
fi

# 5. Summarize
if have python3; then
  echo "INFO aggregating results"
  python3 "$BASE_DIR/scripts/wsl-security-summarize.py" "$RUN_DIR" > "$RUN_DIR/summary.json" 2>&1 || true
fi

echo "DONE check complete. Results in $RUN_DIR"
