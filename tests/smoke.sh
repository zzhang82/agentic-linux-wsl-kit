#!/usr/bin/env bash
set -Eeuo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

echo "== shell syntax =="
for f in scripts/*.sh; do
  bash -n "$f"
  echo "ok $f"
done

echo "== powershell scripts present =="
for f in scripts/*.ps1; do
  test -s "$f"
  echo "ok $f"
done

echo "== skill metadata =="
for f in skills/*/SKILL.md; do
  grep -q '^---$' "$f"
  grep -q '^name:' "$f"
  grep -q '^description:' "$f"
  grep -q '^version:' "$f"
  echo "ok $f"
done

echo "== security routine scripts =="
bash -n scripts/wsl-security-check.sh
echo "ok scripts/wsl-security-check.sh"
bash -n scripts/node-supply-chain-guard.sh
echo "ok scripts/node-supply-chain-guard.sh"
bash -n scripts/safe-npm.sh
echo "ok scripts/safe-npm.sh"
bash -n scripts/safe-npx.sh
echo "ok scripts/safe-npx.sh"
bash -n scripts/safe-pnpm.sh
echo "ok scripts/safe-pnpm.sh"
bash -n scripts/safe-yarn.sh
echo "ok scripts/safe-yarn.sh"
bash -n scripts/safe-bun.sh
echo "ok scripts/safe-bun.sh"
bash scripts/wsl-security-check.sh --list-tools >/tmp/agentic-linux-wsl-kit-tools.txt
echo "ok scripts/wsl-security-check.sh --list-tools"
python3 -m py_compile scripts/wsl-security-summarize.py
echo "ok scripts/wsl-security-summarize.py"
python3 -m py_compile scripts/wsl-maintenance-audit.py
echo "ok scripts/wsl-maintenance-audit.py"

echo "== security docs present =="
test -s docs/security-routine-sop.md
test -s docs/tool-policy.md
test -s docs/agent-active-defense.md
test -s docs/npm-supply-chain-policy.md
echo "ok docs"

echo "== non-destructive script runs =="
bash scripts/linux-doctor.sh >/tmp/agentic-linux-wsl-kit-doctor.txt
bash scripts/linux-doctor.sh --format json >/tmp/agentic-linux-wsl-kit-doctor.jsonl
bash scripts/package-security-update.sh --preview >/tmp/agentic-linux-wsl-kit-update-preview.txt
bash scripts/wsl-security-check.sh --daily >/tmp/agentic-linux-wsl-kit-security-daily.txt
bash scripts/node-supply-chain-guard.sh --preinstall >/tmp/agentic-linux-wsl-kit-guard-pre.txt
bash scripts/node-supply-chain-guard.sh --request "npm install axios" >/tmp/agentic-linux-wsl-kit-guard-req.txt
maintenance_tmp="$(mktemp -d)"
trap 'rm -rf "$maintenance_tmp"' EXIT
python3 scripts/wsl-maintenance-audit.py --quick --output "$maintenance_tmp" --format json >/tmp/agentic-linux-wsl-kit-maintenance-audit.json
python3 - "$maintenance_tmp" <<'PY'
import importlib.util
import json
import os
import sys
import tempfile
from pathlib import Path

root = Path(sys.argv[1])
audit = json.loads((root / "audit.json").read_text(encoding="utf-8"))
assert audit["read_only"] is True
assert audit["safety"]["sudo_used"] is False
assert audit["safety"]["network_refresh_used"] is False
assert audit["safety"]["mutation_commands_used"] == []
assert audit["safety"]["command_ledger"]
assert (root / "report.md").is_file()
assert (root / "audit.json").stat().st_mode & 0o777 == 0o600
assert (root / "report.md").stat().st_mode & 0o777 == 0o600

spec = importlib.util.spec_from_file_location("wsl_maintenance_audit", Path("scripts/wsl-maintenance-audit.py"))
module = importlib.util.module_from_spec(spec)
assert spec.loader is not None
spec.loader.exec_module(module)
assert module.command_is_mutating(["sudo", "true"]) is True
assert module.command_is_mutating(["apt-get", "update"]) is True
for command in (
    ["apt-get", "install", "example"], ["apt-get", "remove", "example"],
    ["journalctl", "--vacuum-size=1M"], ["docker", "--context", "default", "system", "prune"],
    ["docker", "rm", "example"], ["docker", "volume", "rm", "example"], ["docker", "compose", "down"],
    ["docker", "compose", "--project-name", "test", "down"],
    ["docker", "compose", "-f", "compose.yml", "rm"],
    ["docker", "container", "--format", "x", "rm", "id"],
    ["docker", "system", "--format", "x", "prune"],
    ["wsl.exe", "--terminate", "Ubuntu"], ["wsl.exe", "--import", "test", "/tmp/test", "/tmp/test.tar"],
    ["Optimize-VHD", "-Path", "disk.vhdx"],
):
    assert module.command_is_mutating(command) is True, command
for command in (
    ["apt-cache", "policy"], ["docker", "--context", "default", "system", "df"],
    ["docker", "container", "--format", "x", "ls", "-a"],
    ["docker", "compose", "--project-name", "test", "ps"],
    ["docker", "system", "--format", "x", "df"], ["wsl.exe", "--list", "--verbose"],
    ["du", "-s", "/home/example/.sudo_as_admin_successful"],
):
    assert module.command_is_mutating(command) is False, command
assert module.command_is_mutating(["du", "-s", "/home/example/.sudo_as_admin_successful"]) is False
assert module.evidence_complete({"returncode": 1, "stdout": ""}) is False
original_run = module.run
original_which = module.shutil.which
module.shutil.which = lambda name: None if name == "docker" else original_which(name)
docker_missing = module.docker_evidence()
assert docker_missing["available"] is False
assert docker_missing["availability_complete"] is True
assert docker_missing["daemon_reachability_complete"] is False
assert docker_missing["evidence_complete"] is False
docker_missing_findings = []
module.add_docker_findings(docker_missing_findings, docker_missing)
assert any(item["id"] == "docker-evidence-unavailable" and item["classification"] == "REVIEW" for item in docker_missing_findings)
module.shutil.which = lambda name: "/usr/bin/docker" if name == "docker" else original_which(name)
def fake_docker_info_failure(command, timeout=30):
    if command == ["docker", "info"]:
        return {"command": command, "returncode": 1, "stdout": "", "stderr": "daemon unavailable"}
    raise AssertionError(command)
module.run = fake_docker_info_failure
docker_info_failure = module.docker_evidence()
assert docker_info_failure["available"] is True
assert docker_info_failure["availability_complete"] is True
assert docker_info_failure["reachable"] is False
assert docker_info_failure["daemon_reachability_complete"] is True
assert docker_info_failure["evidence_complete"] is False
docker_info_findings = []
module.add_docker_findings(docker_info_findings, docker_info_failure)
assert any(item["id"] == "docker-evidence-unavailable" for item in docker_info_findings)
def fake_docker_run(command, timeout=30):
    if command == ["docker", "info"]:
        return {"command": command, "returncode": 0, "stdout": "ok", "stderr": ""}
    if command[:3] == ["docker", "container", "ls"]:
        return {"command": command, "returncode": 1, "stdout": "", "stderr": "list failed"}
    if command == ["docker", "system", "df"]:
        return {"command": command, "returncode": 1, "stdout": "", "stderr": "df failed"}
    raise AssertionError(command)
module.run = fake_docker_run
docker_failure = module.docker_evidence()
assert docker_failure["availability_complete"] is True
assert docker_failure["daemon_reachability_complete"] is True
assert docker_failure["evidence_complete"] is False
assert docker_failure["container_list_complete"] is False
assert docker_failure["system_df_complete"] is False
assert "list failed" in docker_failure["errors"]
docker_failure_findings = []
module.add_docker_findings(docker_failure_findings, docker_failure)
assert any(item["id"] == "docker-evidence-unavailable" for item in docker_failure_findings)

def docker_inspect_case(inspect_stdout, inspect_returncode=0, inspect_stderr=""):
    def fake_run(command, timeout=30):
        if command == ["docker", "info"]:
            return {"command": command, "returncode": 0, "stdout": "ok", "stderr": ""}
        if command[:3] == ["docker", "container", "ls"]:
            return {"command": command, "returncode": 0, "stdout": "abc123\ndef456", "stderr": ""}
        if command[:4] == ["docker", "container", "inspect", "--size"]:
            return {"command": command, "returncode": inspect_returncode, "stdout": inspect_stdout, "stderr": inspect_stderr}
        if command == ["docker", "system", "df"]:
            return {"command": command, "returncode": 0, "stdout": "TYPE TOTAL", "stderr": ""}
        raise AssertionError(command)
    module.run = fake_run
    result = module.docker_evidence()
    findings = []
    module.add_docker_findings(findings, result)
    assert result["container_inspect_complete"] is False
    assert result["evidence_complete"] is False
    assert result["stopped_containers"] == []
    assert any(item["id"] == "docker-evidence-unavailable" and item["classification"] == "REVIEW" for item in findings)

docker_inspect_case("", inspect_returncode=1, inspect_stderr="inspect failed")
docker_inspect_case("not-json")
docker_inspect_case('{"error":"unexpected"}')
docker_inspect_case('["unexpected"]')
docker_inspect_case('[{"Id":"abc123","Name":"/one","Config":{"Image":"example"},"State":{"Status":"exited"},"SizeRw":1,"SizeRootFs":2}]')
for field in ("Config", "State"):
    for value in (None, [], "wrong"):
        docker_inspect_case(json.dumps([{"Id": "abc123", "Name": "/one", "Config": {"Image": "example"}, "State": {"Status": "exited"}, field: value}, {"Id": "def456", "Name": "/two", "Config": {"Image": "example"}, "State": {"Status": "exited"}}]))
    record = {"Id": "abc123", "Name": "/one", "Config": {"Image": "example"}, "State": {"Status": "exited"}}
    del record[field]
    docker_inspect_case(json.dumps([record, {"Id": "def456", "Name": "/two", "Config": {"Image": "example"}, "State": {"Status": "exited"}}]))
module.run = original_run
module.shutil.which = original_which
with tempfile.TemporaryDirectory() as temp_home:
    home = Path(temp_home)
    protected = home / ".ssh"
    protected.mkdir()
    (protected / "private-key-name-only").write_text("not-read", encoding="utf-8")
    measurable = home / "scratch"
    measurable.mkdir()
    (measurable / "file.txt").write_text("data", encoding="utf-8")
    module.COMMAND_LEDGER.clear()
    entries = module.home_entries(home, quick=False)
    protected_entry = next(item for item in entries if item["name"] == ".ssh")
    assert protected_entry["size_bytes"] is None
    assert protected_entry["measurement"] == "not_recursively_traversed"
    assert all(str(protected) not in " ".join(item["command"]) for item in module.COMMAND_LEDGER)
    output_target = home / "real-output"
    output_target.mkdir()
    output_link = home / "output-link"
    output_link.symlink_to(output_target, target_is_directory=True)
    assert output_link.is_symlink()
    linked_parent = home / "linked-parent"
    linked_parent.symlink_to(output_target, target_is_directory=True)
    try:
        module.reject_symlink_ancestors(linked_parent / "child")
    except RuntimeError:
        pass
    else:
        raise AssertionError("symlinked output parent was accepted")

    def fake_partial_du(command, timeout=30):
        return {"command": command, "returncode": 1, "stdout": f"42\t{command[-1]}", "stderr": "permission denied"}
    module.run = fake_partial_du
    measurement = module.directory_size(home / "scratch")
    assert measurement == {"size_bytes": 42, "complete": False, "error": "permission denied"}
    cache_findings = []
    module.add_developer_cache_findings(cache_findings, [{"path": str(home / ".cache"), **measurement}])
    assert any(item["id"] == "developer-cache-.cache-measurement-incomplete" and item["classification"] == "REVIEW" for item in cache_findings)
    partial_entries = module.home_entries(home, quick=False)
    scratch_entry = next(item for item in partial_entries if item["name"] == "scratch")
    assert scratch_entry["measurement"] == "minimum_recursive_size"
    assert scratch_entry["measurement_complete"] is False
    module.run = original_run
PY
echo "ok scripts/wsl-maintenance-audit.py --quick"
if python3 scripts/wsl-maintenance-audit.py --quick --output "$maintenance_tmp" >/tmp/agentic-linux-wsl-kit-maintenance-overwrite.txt 2>&1; then
  echo "Expected existing audit artifacts to be rejected"
  exit 1
fi
echo "ok scripts/wsl-maintenance-audit.py rejects existing artifacts"
mkdir "$maintenance_tmp/real-output"
ln -s "$maintenance_tmp/real-output" "$maintenance_tmp/output-link"
if python3 scripts/wsl-maintenance-audit.py --quick --output "$maintenance_tmp/output-link" >/tmp/agentic-linux-wsl-kit-maintenance-symlink.txt 2>&1; then
  echo "Expected symlink output path to be rejected"
  exit 1
fi
echo "ok scripts/wsl-maintenance-audit.py rejects symlink output"
mkdir "$maintenance_tmp/real-parent"
ln -s "$maintenance_tmp/real-parent" "$maintenance_tmp/symlink-parent"
if python3 scripts/wsl-maintenance-audit.py --quick --output "$maintenance_tmp/symlink-parent/child" >/tmp/agentic-linux-wsl-kit-maintenance-symlink-parent.txt 2>&1; then
  echo "Expected symlink output parent to be rejected"
  exit 1
fi
echo "ok scripts/wsl-maintenance-audit.py rejects symlink output parent"

echo "== wrapper symlink and alias tests =="
wrapper_tmp="$(mktemp -d)"
ln -s "$(pwd)/scripts/safe-npm.sh" "$wrapper_tmp/npm"
ln -s "$(pwd)/scripts/safe-yarn.sh" "$wrapper_tmp/yarn"
ln -s "$(pwd)/scripts/safe-pnpm.sh" "$wrapper_tmp/pnpm"
ln -s "$(pwd)/scripts/safe-bun.sh" "$wrapper_tmp/bun"

npm_ci_out="$("$wrapper_tmp/npm" ci 2>&1 || true)"
if echo "$npm_ci_out" | grep -q "BLOCKED: raw npm ci is not allowed"; then
  echo "ok symlinked npm ci blocked"
else
  echo "FAIL symlinked npm ci not blocked: $npm_ci_out"
  exit 1
fi

npm_i_out="$("$wrapper_tmp/npm" i axios 2>&1 || true)"
if echo "$npm_i_out" | grep -q "BLOCKED: raw npm i is not allowed"; then
  echo "ok symlinked npm i blocked"
else
  echo "FAIL symlinked npm i not blocked: $npm_i_out"
  exit 1
fi

yarn_out="$("$wrapper_tmp/yarn" 2>&1 || true)"
if echo "$yarn_out" | grep -q "BLOCKED: raw yarn install is not allowed"; then
  echo "ok symlinked bare yarn blocked"
else
  echo "FAIL symlinked bare yarn not blocked: $yarn_out"
  exit 1
fi

pnpm_out="$("$wrapper_tmp/pnpm" i 2>&1 || true)"
if echo "$pnpm_out" | grep -q "BLOCKED: raw pnpm i is not allowed"; then
  echo "ok symlinked pnpm i blocked"
else
  echo "FAIL symlinked pnpm i not blocked: $pnpm_out"
  exit 1
fi

# Test leading option bypass resistance and ensure fake real npm is never called
fake_bin="$(mktemp -d)"
fake_log="$fake_bin/fake_invoked.log"
cat <<SH > "$fake_bin/npm"
#!/bin/sh
echo "INVOKED \$*" >> "$fake_log"
exit 0
SH
chmod +x "$fake_bin/npm"

# Positive control: verify that direct stub invocation creates the sentinel log
"$fake_bin/npm" positive_control_probe
if [ -f "$fake_log" ] && grep -q "INVOKED positive_control_probe" "$fake_log"; then
  echo "ok fake real npm sentinel probe verified"
  rm -f "$fake_log"
else
  echo "FAIL fake real npm sentinel probe did not record invocation"
  exit 1
fi

prefix_out="$(PATH="$fake_bin:$PATH" "$wrapper_tmp/npm" --prefix /tmp/project ci 2>&1 || true)"
if echo "$prefix_out" | grep -q "BLOCKED: raw npm ci is not allowed"; then
  echo "ok npm with leading --prefix ci blocked"
else
  echo "FAIL npm with leading --prefix ci not blocked: $prefix_out"
  exit 1
fi

registry_out="$(PATH="$fake_bin:$PATH" "$wrapper_tmp/npm" --registry https://registry.npmjs.org/ ci 2>&1 || true)"
if echo "$registry_out" | grep -q "BLOCKED: raw npm ci is not allowed"; then
  echo "ok npm with leading --registry ci blocked"
else
  echo "FAIL npm with leading --registry ci not blocked: $registry_out"
  exit 1
fi

if [ -f "$fake_log" ]; then
  echo "FAIL fake real npm was invoked despite wrapper interception: $(cat "$fake_log")"
  rm -f "$fake_log"
  exit 1
fi
echo "ok fake real npm was not reached"

# Test pnpm -w install blocking and ensure real pnpm is not reached
cat <<SH > "$fake_bin/pnpm"
#!/bin/sh
echo "INVOKED \$*" >> "$fake_log"
exit 0
SH
chmod +x "$fake_bin/pnpm"

# Positive control for pnpm stub
"$fake_bin/pnpm" positive_control_probe
if [ -f "$fake_log" ] && grep -q "INVOKED positive_control_probe" "$fake_log"; then
  echo "ok fake real pnpm sentinel probe verified"
  rm -f "$fake_log"
else
  echo "FAIL fake real pnpm sentinel probe did not record invocation"
  exit 1
fi

pnpm_w_out="$(PATH="$fake_bin:$PATH" "$wrapper_tmp/pnpm" -w install 2>&1 || true)"
if echo "$pnpm_w_out" | grep -q "BLOCKED: raw pnpm install is not allowed"; then
  echo "ok pnpm -w install blocked"
else
  echo "FAIL pnpm -w install not blocked: $pnpm_w_out"
  exit 1
fi

if [ -f "$fake_log" ]; then
  echo "FAIL fake real pnpm was invoked despite wrapper interception: $(cat "$fake_log")"
  rm -f "$fake_log"
  exit 1
fi
echo "ok fake real pnpm was not reached"
rm -rf "$fake_bin"

# Test scanner error detection in summarizer and driver
scan_err_tmp="$(mktemp -d)"
cat <<'EOF' > "$scan_err_tmp/manifest.json"
{"mode": "preflight", "timestamp_utc": "2026-10-27T00:00:00Z", "project_path": "/tmp"}
EOF
echo "Gitleaks crash exit code: 2" > "$scan_err_tmp/gitleaks-error.txt"
summary_res="$(python3 scripts/wsl-security-summarize.py "$scan_err_tmp")"
if echo "$summary_res" | grep -q '"status": "FAIL"'; then
  echo "ok scanner execution error correctly reported as FAIL status"
else
  echo "FAIL scanner execution error not reported as FAIL: $summary_res"
  exit 1
fi
rm -rf "$scan_err_tmp"

# Test TruffleHog error detection in summarizer
th_err_tmp="$(mktemp -d)"
cat <<'EOF' > "$th_err_tmp/manifest.json"
{"mode": "monthly", "timestamp_utc": "2026-10-27T00:00:00Z", "project_path": "/tmp"}
EOF
echo "permission denied /root" > "$th_err_tmp/trufflehog-error.txt"
th_summary_res="$(python3 scripts/wsl-security-summarize.py "$th_err_tmp")"
if echo "$th_summary_res" | grep -q '"source": "trufflehog"' && echo "$th_summary_res" | grep -q '"level": "FAIL"'; then
  echo "ok trufflehog silent/permission error correctly reported as FAIL status"
else
  echo "FAIL trufflehog runtime error not reported as FAIL: $th_summary_res"
  exit 1
fi
rm -rf "$th_err_tmp"

# End-to-end scanner failure propagation through security check driver
mock_scan_bin="$(mktemp -d)"
cat <<'SH' > "$mock_scan_bin/gitleaks"
#!/bin/sh
exit 2
SH
chmod +x "$mock_scan_bin/gitleaks"
test_proj="$(mktemp -d)"
git -C "$test_proj" init -q
set +e
PATH="$mock_scan_bin:$PATH" bash scripts/wsl-security-check.sh --preflight --project "$test_proj" >/tmp/mock_scan_out.txt 2>&1
check_exit=$?
set -e
rm -rf "$mock_scan_bin" "$test_proj" /tmp/mock_scan_out.txt
if [ "$check_exit" -ne 0 ]; then
  echo "ok scanner execution failure triggers non-zero driver exit"
else
  echo "FAIL driver returned 0 despite scanner runtime failure"
  exit 1
fi

pkg_check_out="$(bash scripts/package-security-check.sh)"
if echo "$pkg_check_out" | grep -q "using local package metadata"; then
  echo "ok package-security-check is read-only by default"
else
  echo "FAIL package-security-check did not report local metadata default: $pkg_check_out"
  exit 1
fi
rm -rf "$wrapper_tmp"

echo "== secret scan sanity =="
if grep -RInE '(apiKey|BEGIN (RSA|OPENSSH|PRIVATE) KEY|password\s*=|token\s*=)' README.md docs scripts skills 2>/dev/null; then
  echo "Potential secret-like text found. Review output above."
  exit 1
fi

echo "PASS smoke tests"
