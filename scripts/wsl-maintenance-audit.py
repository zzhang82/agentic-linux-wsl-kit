#!/usr/bin/env python3
"""Read-only WSL/Linux maintenance evidence and classification audit."""

from __future__ import annotations

import argparse
import json
import os
import re
import shutil
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Any


VERSION = "0.1.0"
MIB = 1024**2
GIB = 1024**3
COMMAND_LEDGER: list[dict[str, Any]] = []
PROTECTED_HOME_NAMES = {
    ".ssh",
    ".gnupg",
    ".aws",
    ".config",
    ".local",
    ".kube",
    ".docker",
    ".runtime-agents",
    ".codex",
    ".opencode",
    ".hermes",
    ".claude",
    ".claude-code-router",
    ".gemini",
    ".cursor",
    ".agents",
    "code",
    "projects",
    "obsidian-vault-backups",
    "Unity",
}
MUTATION_DENYLIST = (
    "sudo",
    "apt/apt-get update|upgrade|install|remove|purge|autoremove|clean|autoclean",
    "journalctl --vacuum-*",
    "docker rm|rmi; docker system|container|image|volume|network|builder|plugin|secret|config prune|rm; docker compose down|rm",
    "wsl/wsl.exe --install|--shutdown|--terminate|--unregister|--export|--import",
    "optimize-vhd|resize-vhd|compact-vhd|dismount-vhd",
)


def command_is_mutating(command: list[str]) -> bool:
    """Reject supported destructive direct argv command forms.

    The guard evaluates argv passed by this audit's static collectors. It does
    not interpret shell wrappers or arbitrary command-language input.
    """
    if not command:
        return False
    executable = Path(command[0]).name.lower()
    args = [part.lower() for part in command[1:]]
    if executable == "sudo" or executable in {"optimize-vhd", "resize-vhd", "compact-vhd", "dismount-vhd"}:
        return True
    if executable in {"apt", "apt-get"} and any(
        action in args for action in {"update", "upgrade", "dist-upgrade", "full-upgrade", "install", "remove", "purge", "reinstall", "autoremove", "clean", "autoclean"}
    ):
        return True
    if executable == "journalctl" and any(arg.startswith("--vacuum-") for arg in args):
        return True
    if executable == "docker":
        docker_args = docker_subcommand_args(args)
        if docker_args and docker_args[0] in {"rm", "rmi"}:
            return True
        if not docker_args:
            return False
        group, verb = docker_args[0], docker_group_verb(docker_args)
        if group == "compose":
            return verb in {"down", "rm"}
        if group in {"system", "container", "image", "volume", "network", "builder", "buildx", "plugin", "secret", "config"}:
            return verb in {"prune", "rm", "remove"}
        return False
    if executable in {"wsl", "wsl.exe"} and any(
        action in args for action in {"--install", "--shutdown", "--terminate", "--unregister", "--export", "--import", "--import-in-place"}
    ):
        return True
    return False


def docker_subcommand_args(args: list[str]) -> list[str]:
    """Remove leading Docker global options before evaluating a subcommand."""
    options_with_values = {"--config", "-c", "--context", "-h", "--host", "-l", "--log-level"}
    index = 0
    while index < len(args):
        arg = args[index]
        if arg == "--":
            return args[index + 1 :]
        if not arg.startswith("-"):
            return args[index:]
        index += 1 if "=" in arg or arg not in options_with_values else 2
    return []


def docker_group_verb(args: list[str]) -> str | None:
    """Return a supported Docker group verb after scoped options.

    This intentionally bounded argv parser is not a general Docker or shell
    parser. Its option sets cover destructive groups the audit guard handles.
    """
    if len(args) < 2:
        return None
    options_with_values = {
        "compose": {"--project-name", "-p", "--file", "-f", "--env-file", "--profile", "--project-directory", "--ansi"},
        "system": {"--format"},
        "container": {"--format", "--filter", "--signal", "--time"},
        "image": {"--format", "--filter"},
        "volume": {"--format", "--filter", "--driver", "-d", "--opt", "-o", "--label"},
        "network": {"--format", "--filter", "--driver", "-d", "--label", "--scope", "--ipam-driver", "--subnet", "--gateway", "--aux-address"},
        "builder": {"--format", "--filter", "--keep-storage"},
        "buildx": {"--builder", "--progress"},
        "plugin": {"--format", "--filter"},
        "secret": {"--format", "--filter", "--driver", "-d", "--label", "-l"},
        "config": {"--format", "--filter", "--label", "-l"},
    }.get(args[0], set())
    index = 1
    while index < len(args):
        arg = args[index]
        if arg == "--":
            return args[index + 1] if index + 1 < len(args) else None
        if not arg.startswith("-"):
            return arg
        index += 1 if "=" in arg or arg not in options_with_values else 2
    return None


def run(command: list[str], timeout: int = 30) -> dict[str, Any]:
    if command_is_mutating(command):
        COMMAND_LEDGER.append({"command": command, "executed": False, "blocked": True, "returncode": None})
        raise RuntimeError(f"mutation command blocked in audit mode: {' '.join(command)}")
    try:
        result = subprocess.run(
            command,
            capture_output=True,
            text=True,
            timeout=timeout,
            check=False,
        )
        record = {
            "command": command,
            "returncode": result.returncode,
            "stdout": result.stdout.strip(),
            "stderr": result.stderr.strip(),
        }
        COMMAND_LEDGER.append(
            {"command": command, "executed": True, "blocked": False, "returncode": result.returncode}
        )
        return record
    except (FileNotFoundError, subprocess.TimeoutExpired) as exc:
        record = {
            "command": command,
            "returncode": None,
            "stdout": "",
            "stderr": str(exc),
        }
        COMMAND_LEDGER.append(
            {
                "command": command,
                "executed": False,
                "blocked": False,
                "returncode": None,
                "error_type": type(exc).__name__,
            }
        )
        return record


def evidence_complete(result: dict[str, Any], require_output: bool = False) -> bool:
    if result.get("returncode") != 0:
        return False
    if require_output and not result.get("stdout"):
        return False
    return True


def command_uses_network_refresh(command: list[str]) -> bool:
    if not command:
        return False
    executable = Path(command[0]).name.lower()
    args = [part.lower() for part in command[1:]]
    if executable in {"apt", "apt-get"} and "update" in args:
        return True
    if executable == "bash" and any(part.endswith("package-security-check.sh") for part in args):
        return "--no-network" not in args
    return False


def parse_ndjson(text: str) -> list[dict[str, Any]]:
    records: list[dict[str, Any]] = []
    for line in text.splitlines():
        try:
            value = json.loads(line)
        except json.JSONDecodeError:
            continue
        if isinstance(value, dict):
            records.append(value)
    return records


def directory_size(path: Path) -> dict[str, Any]:
    if not path.exists():
        return {"size_bytes": None, "complete": False, "error": "path does not exist"}
    result = run(["du", "-s", "-B1", "--", str(path)], timeout=120)
    if not result["stdout"]:
        return {"size_bytes": None, "complete": False, "error": result["stderr"] or "no size output"}
    try:
        size = int(result["stdout"].split()[0])
    except (ValueError, IndexError):
        return {"size_bytes": None, "complete": False, "error": "unparseable size output"}
    return {
        "size_bytes": size,
        "complete": result["returncode"] == 0,
        "error": result["stderr"] or None,
    }


def human_bytes(value: int | None) -> str:
    if value is None:
        return "unknown"
    size = float(value)
    for unit in ("B", "KiB", "MiB", "GiB", "TiB"):
        if size < 1024 or unit == "TiB":
            return f"{size:.2f} {unit}"
        size /= 1024
    return f"{value} B"


def parse_journal_bytes(text: str) -> int | None:
    match = re.search(r"([0-9.]+)([KMGTP])", text, re.IGNORECASE)
    if not match:
        return None
    power = {"K": 1, "M": 2, "G": 3, "T": 4, "P": 5}[match.group(2).upper()]
    return int(float(match.group(1)) * (1024**power))


def disk_record(path: Path) -> dict[str, Any] | None:
    if not path.exists():
        return None
    usage = shutil.disk_usage(path)
    used_percent = round(100 * usage.used / usage.total, 1) if usage.total else 0.0
    return {
        "path": str(path),
        "total_bytes": usage.total,
        "used_bytes": usage.used,
        "free_bytes": usage.free,
        "used_percent": used_percent,
    }


def os_release() -> dict[str, str]:
    values: dict[str, str] = {}
    path = Path("/etc/os-release")
    if not path.is_file():
        return values
    for line in path.read_text(encoding="utf-8", errors="replace").splitlines():
        if "=" not in line:
            continue
        key, value = line.split("=", 1)
        values[key] = value.strip().strip('"')
    return values


def top_level_sizes(paths: list[Path]) -> dict[str, Any]:
    if not paths:
        return {"sizes": {}, "complete": True, "error": None}
    result = run(["du", "-s", "-B1", "--", *[str(path) for path in paths]], timeout=300)
    sizes: dict[str, int | None] = {str(path): None for path in paths}
    for line in result["stdout"].splitlines():
        fields = line.split(maxsplit=1)
        if len(fields) != 2:
            continue
        try:
            sizes[fields[1]] = int(fields[0])
        except ValueError:
            continue
    return {
        "sizes": sizes,
        "complete": result["returncode"] == 0,
        "error": result["stderr"] or (None if result["returncode"] == 0 else "top-level home sizing failed"),
    }


def home_entries(home: Path, quick: bool) -> list[dict[str, Any]]:
    if quick:
        return []
    try:
        paths = list(home.iterdir())
    except OSError:
        return []
    protected_paths = [path for path in paths if path.name in PROTECTED_HOME_NAMES]
    measurable_paths = [path for path in paths if path.name not in PROTECTED_HOME_NAMES]
    sizing = top_level_sizes(measurable_paths)
    sizes = sizing["sizes"]
    records: list[dict[str, Any]] = []
    for path in paths:
        try:
            item_type = "directory" if path.is_dir() else "file"
        except OSError:
            item_type = "unknown"
        protected_item = path in protected_paths
        size = None if protected_item and item_type == "directory" else sizes.get(str(path))
        if protected_item and item_type == "file":
            try:
                size = path.stat().st_size
            except OSError:
                size = None
        records.append(
            {
                "name": path.name,
                "path": str(path),
                "type": item_type,
                "size_bytes": size,
                "classification": "KEEP_ACTIVE" if protected_item else "REVIEW",
                "measurement": (
                    "not_recursively_traversed" if protected_item
                    else ("recursive_size" if sizing["complete"] else "minimum_recursive_size")
                ),
                "measurement_complete": None if protected_item else sizing["complete"],
                "measurement_error": None if protected_item else sizing["error"],
                "reason": (
                    "protected credential/config/runtime root; not recursively traversed"
                    if protected_item
                    else (
                        "minimum measured total; top-level sizing was incomplete: " + (sizing["error"] or "unknown error")
                        if not sizing["complete"] else "size is not proof of staleness"
                    )
                ),
            }
        )
    records.sort(key=lambda item: item["size_bytes"] or -1, reverse=True)
    return records


def docker_evidence() -> dict[str, Any]:
    if shutil.which("docker") is None:
        return {
            "available": False,
            "availability_complete": True,
            "reachable": False,
            "daemon_reachability_complete": False,
            "evidence_complete": False,
            "container_list_complete": False,
            "container_inspect_complete": False,
            "system_df_complete": False,
            "stopped_containers": [],
            "system_df": "",
            "errors": ["docker executable not found; Docker storage evidence unavailable"],
        }
    info = run(["docker", "info"], timeout=20)
    if info["returncode"] != 0:
        return {
            "available": True,
            "availability_complete": True,
            "reachable": False,
            "daemon_reachability_complete": info["returncode"] is not None,
            "evidence_complete": False,
            "container_list_complete": False,
            "container_inspect_complete": False,
            "system_df_complete": False,
            "error": info["stderr"] or info["stdout"],
            "errors": [info["stderr"] or info["stdout"] or "docker info failed"],
            "stopped_containers": [],
            "system_df": "",
        }
    ids_result = run(
        ["docker", "container", "ls", "-a", "--filter", "status=exited", "--format", "{{.ID}}"],
        timeout=20,
    )
    stopped: list[dict[str, Any]] = []
    errors: list[str] = []
    list_complete = evidence_complete(ids_result)
    if not list_complete:
        errors.append(ids_result["stderr"] or ids_result["stdout"] or "docker container list failed")
    ids = [line.strip() for line in ids_result["stdout"].splitlines() if line.strip()]
    inspect_complete = list_complete and not ids
    if ids:
        inspect = run(["docker", "container", "inspect", "--size", *ids], timeout=30)
        if inspect["returncode"] == 0 and inspect["stdout"]:
            try:
                data = json.loads(inspect["stdout"])
            except json.JSONDecodeError:
                data = []
                errors.append("docker container inspect returned unparseable JSON")
            inspect_complete = isinstance(data, list) and len(data) == len(ids) and all(isinstance(item, dict) for item in data)
            if not isinstance(data, list):
                errors.append("docker container inspect JSON must be a list of records")
            elif len(data) != len(ids):
                errors.append("docker container inspect record count does not match stopped-container list")
            for index, item in enumerate(data if isinstance(data, list) else [], start=1):
                if not isinstance(item, dict):
                    errors.append(f"docker container inspect record {index} must be an object")
                    inspect_complete = False
                    continue
                for field in ("Config", "State"):
                    if not isinstance(item.get(field), dict):
                        errors.append(f"docker container inspect record {index} {field} must be an object")
                        inspect_complete = False
            if inspect_complete:
                for item in data:
                    stopped.append(
                        {
                            "id": item.get("Id", "")[:12],
                            "name": str(item.get("Name", "")).lstrip("/"),
                            "image": item["Config"].get("Image", ""),
                            "status": item["State"].get("Status", "unknown"),
                            "size_rw_bytes": item.get("SizeRw") or 0,
                            "size_rootfs_bytes": item.get("SizeRootFs") or 0,
                            "classification": "REVIEW",
                            "reason": "stopped container data requires owner/purpose confirmation before removal",
                        }
                    )
        else:
            inspect_complete = False
            errors.append(inspect["stderr"] or inspect["stdout"] or "docker container inspect failed")
    system_df = run(["docker", "system", "df"], timeout=30)
    system_df_complete = evidence_complete(system_df, require_output=True)
    if not system_df_complete:
        errors.append(system_df["stderr"] or system_df["stdout"] or "docker system df failed")
    return {
        "available": True,
        "availability_complete": True,
        "reachable": True,
        "daemon_reachability_complete": True,
        "evidence_complete": list_complete and inspect_complete and system_df_complete,
        "container_list_complete": list_complete,
        "container_inspect_complete": inspect_complete,
        "system_df_complete": system_df_complete,
        "stopped_containers": stopped,
        "system_df": system_df["stdout"],
        "errors": errors,
    }


def add_finding(
    findings: list[dict[str, Any]],
    finding_id: str,
    classification: str,
    area: str,
    evidence: str,
    next_action: str,
    approval_required: bool = False,
) -> None:
    findings.append(
        {
            "id": finding_id,
            "classification": classification,
            "area": area,
            "evidence": evidence,
            "next_action": next_action,
            "approval_required": approval_required,
        }
    )


def add_docker_findings(findings: list[dict[str, Any]], docker: dict[str, Any]) -> None:
    stopped = docker.get("stopped_containers", [])
    if stopped:
        stopped_names = ", ".join(item["name"] for item in stopped)
        stopped_size = sum(item.get("size_rw_bytes", 0) for item in stopped)
        add_finding(
            findings,
            "docker-stopped-containers",
            "REVIEW",
            "docker",
            f"{len(stopped)} stopped containers ({stopped_names}) use {human_bytes(stopped_size)} writable data",
            "Confirm exact owners and whether each container is disposable; never use generic prune.",
        )
    if not docker.get("evidence_complete"):
        add_finding(
            findings,
            "docker-evidence-unavailable",
            "REVIEW",
            "docker",
            "Docker evidence is incomplete: " + "; ".join(docker.get("errors") or [docker.get("error", "unknown error")]),
            "Restore read-only Docker visibility before classifying container or image storage.",
        )


def add_developer_cache_findings(findings: list[dict[str, Any]], developer_caches: list[dict[str, Any]]) -> None:
    for item in developer_caches:
        if not item["complete"]:
            size_str = human_bytes(item["size_bytes"]) if item["size_bytes"] is not None else "unavailable"
            add_finding(
                findings,
                f"developer-cache-{Path(item['path']).name}-measurement-incomplete",
                "REVIEW",
                "cache",
                f"{item['path']} minimum measured total is {size_str}; measurement incomplete: {item['error'] or 'unknown error'}",
                "Restore read-only visibility before classifying this developer cache by size.",
            )
        elif (item["size_bytes"] or 0) >= GIB:
            add_finding(
                findings,
                f"developer-cache-{Path(item['path']).name}",
                "REVIEW",
                "cache",
                f"{item['path']} uses {human_bytes(item['size_bytes'])}",
                "Confirm offline/re-download needs before proposing exact cache cleanup.",
            )


def render_report(audit: dict[str, Any]) -> str:
    lines = [
        "# WSL Safe Maintenance Audit",
        "",
        f"- Timestamp: `{audit['timestamp_utc']}`",
        "- Mode: **READ-ONLY**",
        f"- Overall status: **{audit['summary']['status']}**",
        f"- Output directory: `{audit['output_directory']}`",
        "",
        "## Safety",
        "",
        f"- Sudo used: `{audit['safety']['sudo_used']}`.",
        f"- Package metadata refresh used: `{audit['safety']['network_refresh_used']}`.",
        f"- Executed mutation commands: `{len(audit['safety']['mutation_commands_used'])}`.",
        "- Home entries are represented by name, type, and size only; contents were not inspected or printed.",
        "- `audit.json` contains operational metadata such as paths, tool locations, groups, and Docker names; report files are owner-readable only.",
        "",
        "## System",
        "",
        f"- OS: `{audit['system'].get('pretty_name', 'unknown')}`",
        f"- Kernel: `{audit['system'].get('kernel', 'unknown')}`",
        f"- WSL detected: `{audit['system'].get('wsl_detected')}`",
        f"- Failed systemd units: `{audit['system'].get('failed_systemd_units')}`",
        f"- dpkg audit lines: `{audit['packages'].get('dpkg_audit_lines')}`",
        f"- Locally visible package upgrades: `{audit['packages'].get('upgradable_count')}`",
        "",
        "## Storage",
        "",
        "| Path | Used | Free | Used % |",
        "| --- | ---: | ---: | ---: |",
    ]
    for disk in audit["storage"]["disks"]:
        lines.append(
            f"| `{disk['path']}` | {human_bytes(disk['used_bytes'])} | {human_bytes(disk['free_bytes'])} | {disk['used_percent']}% |"
        )
    lines.extend(
        [
            "",
            f"- APT cache: **{human_bytes(audit['storage']['apt_cache_bytes'])}**"
            + (" (minimum measured; unreadable entries exist)" if not audit['storage']['apt_cache_measurement_complete'] else ""),
            f"- Journal usage: **{human_bytes(audit['storage']['journal_bytes'])}**",
            "- Linux filesystem free space is not evidence of the Windows host `ext4.vhdx` physical size.",
            "",
            "## Selected Developer Caches",
            "",
            "| Path | Size |",
            "| --- | ---: |",
        ]
    )
    for item in audit["storage"]["developer_caches"]:
        lines.append(f"| `{item['path']}` | {human_bytes(item['size_bytes'])} |")
    lines.extend(["", "## Docker", ""])
    docker = audit["docker"]
    lines.append(f"- Available: `{docker.get('available')}`; reachable: `{docker.get('reachable')}`")
    if docker.get("stopped_containers"):
        lines.extend(
            [
                "",
                "| Container | Image | Writable size | Classification |",
                "| --- | --- | ---: | --- |",
            ]
        )
        for item in docker["stopped_containers"]:
            lines.append(
                f"| `{item['name']}` | `{item['image']}` | {human_bytes(item['size_rw_bytes'])} | {item['classification']} |"
            )
    lines.extend(["", "```text", docker.get("system_df") or "Docker storage summary unavailable", "```"])
    lines.extend(
        [
            "",
            "## Classifications",
            "",
            "| ID | Class | Area | Evidence | Next action |",
            "| --- | --- | --- | --- | --- |",
        ]
    )
    for item in audit["findings"]:
        evidence = item["evidence"].replace("|", "/")
        action = item["next_action"].replace("|", "/")
        lines.append(f"| `{item['id']}` | {item['classification']} | {item['area']} | {evidence} | {action} |")
    home = audit["storage"]["home_top_level"]
    if home:
        lines.extend(
            [
                "",
                "## Largest Home Entries",
                "",
                "| Name | Size | Class | Reason |",
                "| --- | ---: | --- | --- |",
            ]
        )
        for item in home[:20]:
            lines.append(
                f"| `{item['name']}` | {human_bytes(item['size_bytes'])} | {item['classification']} | {item['reason']} |"
            )
        protected_home = [item for item in home if item.get("measurement") == "not_recursively_traversed"]
        if protected_home:
            lines.extend(
                [
                    "",
                    "## Protected Home Roots Not Traversed",
                    "",
                    "| Name | Type | Classification |",
                    "| --- | --- | --- |",
                ]
            )
            for item in protected_home:
                lines.append(f"| `{item['name']}` | {item['type']} | {item['classification']} |")
    lines.extend(
        [
            "",
            "## Stop Boundary",
            "",
            "This audit does not approve cleanup. Any next action must name exact packages, paths, containers, or Windows-side commands and include rollback or recovery evidence.",
            "",
        ]
    )
    return "\n".join(lines)


def reject_symlink_ancestors(path: Path) -> None:
    """Reject an output target if it or any existing lexical ancestor is a symlink."""
    absolute = path.absolute()
    for candidate in (absolute, *absolute.parents):
        if candidate.is_symlink():
            raise RuntimeError(f"refusing output path with symlink ancestor: {candidate}")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, help="Output directory for audit.json and report.md")
    parser.add_argument("--quick", action="store_true", help="Skip full home-root sizing for smoke tests")
    parser.add_argument("--format", choices=("text", "json"), default="text")
    args = parser.parse_args()
    COMMAND_LEDGER.clear()
    os.umask(0o077)

    timestamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    output = args.output or Path.home() / ".local" / "state" / "wsl-maintenance" / f"audit-{timestamp}"
    reject_symlink_ancestors(output)
    if output.exists() and not output.is_dir():
        raise RuntimeError(f"output path is not a directory: {output}")
    output.mkdir(parents=True, exist_ok=True, mode=0o700)
    reject_symlink_ancestors(output)
    if not output.is_dir():
        raise RuntimeError(f"output path is not a directory: {output}")
    audit_path = output / "audit.json"
    report_path = output / "report.md"
    for artifact in (audit_path, report_path):
        if artifact.exists() or artifact.is_symlink():
            raise RuntimeError(f"refusing to overwrite existing audit artifact: {artifact}")

    repo_root = Path(__file__).resolve().parent.parent
    home = Path.home()
    doctor = run(["bash", str(repo_root / "scripts" / "linux-doctor.sh"), "--format", "json"], timeout=120)
    package_check = run(
        ["bash", str(repo_root / "scripts" / "package-security-check.sh"), "--no-network", "--format", "json"],
        timeout=120,
    )
    doctor_records = parse_ndjson(doctor["stdout"])
    package_records = parse_ndjson(package_check["stdout"])

    release = os_release()
    kernel_result = run(["uname", "-r"])
    kernel = kernel_result["stdout"]
    proc_version = Path("/proc/version")
    wsl_detected = proc_version.is_file() and "microsoft" in proc_version.read_text(
        encoding="utf-8", errors="replace"
    ).lower()
    failed_units_result = run(["systemctl", "--failed", "--no-legend", "--plain"])
    failed_units_complete = evidence_complete(failed_units_result)
    failed_units = (
        len([line for line in failed_units_result["stdout"].splitlines() if line.strip()])
        if failed_units_complete
        else None
    )
    dpkg_audit = run(["dpkg", "--audit"], timeout=60)
    dpkg_complete = evidence_complete(dpkg_audit)
    dpkg_lines = len([line for line in dpkg_audit["stdout"].splitlines() if line.strip()]) if dpkg_complete else None
    package_check_complete = evidence_complete(package_check) and bool(package_records)
    upgradable_count = None
    if package_check_complete:
        for record in package_records:
            message = str(record.get("message", ""))
            match = re.search(r"upgradable packages:\s*(\d+)", message)
            if match:
                upgradable_count = int(match.group(1))
                break
        if upgradable_count is None:
            package_check_complete = False
    holds = run(["apt-mark", "showhold"])
    holds_complete = evidence_complete(holds)

    journal = run(["journalctl", "--disk-usage"], timeout=60)
    journal_bytes = parse_journal_bytes(f"{journal['stdout']} {journal['stderr']}")
    journal_complete = evidence_complete(journal) and journal_bytes is not None
    apt_cache = directory_size(Path("/var/cache/apt/archives"))
    cache_paths = [
        home / ".cache",
        home / ".npm",
        home / ".bun",
        home / ".gradle" / "caches",
    ]
    developer_caches = []
    for path in cache_paths:
        if path.exists():
            measurement = directory_size(path)
            developer_caches.append({"path": str(path), **measurement})
    disks = [record for path in (Path("/"), Path("/mnt/c")) if (record := disk_record(path)) is not None]
    docker = docker_evidence()
    home_top = home_entries(home, args.quick)

    findings: list[dict[str, Any]] = []
    if not args.quick and not home_top and home.exists():
        add_finding(
            findings,
            "home-enumeration-failed",
            "REVIEW",
            "home",
            f"Failed to enumerate home directory {home}",
            "Verify home directory permissions before assessing storage.",
        )
    doctor_complete = evidence_complete(doctor) and bool(doctor_records)
    if not doctor_complete:
        add_finding(
            findings,
            "linux-doctor-unavailable",
            "REVIEW",
            "health",
            f"linux-doctor evidence unavailable or incomplete: {doctor['stderr'] or doctor['stdout'] or 'no records'}",
            "Repair the baseline doctor before making a maintenance recommendation.",
        )
    root_disk = next((item for item in disks if item["path"] == "/"), None)
    if root_disk:
        if root_disk["used_percent"] >= 90:
            classification = "APPROVAL_REQUIRED"
            action = "Prepare a bounded capacity plan; do not delete by size alone."
            approval = True
        elif root_disk["used_percent"] >= 80:
            classification = "REVIEW"
            action = "Attribute growth before proposing cleanup."
            approval = False
        else:
            classification = "KEEP_ACTIVE"
            action = "No capacity action needed."
            approval = False
        add_finding(
            findings,
            "root-capacity",
            classification,
            "disk",
            f"root filesystem is {root_disk['used_percent']}% used",
            action,
            approval,
        )
    windows_c = next((item for item in disks if item["path"] == "/mnt/c"), None)
    if windows_c:
        add_finding(
            findings,
            "windows-c-capacity",
            "REVIEW" if windows_c["used_percent"] >= 80 else "KEEP_ACTIVE",
            "windows-side",
            f"Windows C: mount is {windows_c['used_percent']}% used",
            (
                "Use a separate Windows storage audit; do not infer Linux cleanup targets from Windows mount usage."
                if windows_c["used_percent"] >= 80
                else "No Windows capacity action indicated by this threshold."
            ),
        )
    if package_check_complete:
        add_finding(
            findings,
            "package-updates",
            "APPROVAL_REQUIRED" if upgradable_count else "KEEP_ACTIVE",
            "packages",
            f"{upgradable_count} locally visible package upgrades; metadata was not refreshed",
            "Review exact package changes before any approved update batch." if upgradable_count else "No package action indicated.",
            bool(upgradable_count),
        )
    else:
        add_finding(
            findings,
            "package-updates-unavailable",
            "REVIEW",
            "packages",
            f"package evidence unavailable or incomplete: {package_check['stderr'] or package_check['stdout'] or 'no parseable count'}",
            "Repair the read-only package check before classifying update state.",
        )
    add_finding(
        findings,
        "apt-cache",
        "REVIEW" if not apt_cache["complete"] or (apt_cache["size_bytes"] or 0) >= 256 * MIB else "KEEP_ACTIVE",
        "cache",
        (
            f"APT archive cache uses {human_bytes(apt_cache['size_bytes'])}"
            if apt_cache["complete"]
            else f"APT archive cache minimum measured total is {human_bytes(apt_cache['size_bytes'])}; measurement incomplete: {apt_cache['error'] or 'unknown error'}"
        ),
        "Decide whether re-download cost justifies an exact cache-clean action.",
    )
    if journal_complete:
        add_finding(
            findings,
            "journals",
            "REVIEW" if (journal_bytes or 0) >= 512 * MIB else "KEEP_ACTIVE",
            "logs",
            f"journals use {human_bytes(journal_bytes)}",
            "Keep unless retention or capacity evidence justifies a bounded vacuum plan.",
        )
    else:
        add_finding(
            findings,
            "journals-unavailable",
            "REVIEW",
            "logs",
            f"journal usage evidence unavailable: {journal['stderr'] or journal['stdout'] or 'no parseable size'}",
            "Do not classify journal retention until evidence is available.",
        )
    add_developer_cache_findings(findings, developer_caches)
    incomplete_home_entries = [item for item in home_top if item.get("measurement_complete") is False]
    if incomplete_home_entries:
        add_finding(
            findings,
            "home-sizing-incomplete",
            "REVIEW",
            "home-storage",
            "home top-level sizing is incomplete; reported values are minimum measured totals: "
            + "; ".join(sorted({item.get("measurement_error") or "unknown error" for item in incomplete_home_entries})),
            "Restore read-only visibility before using home-size evidence for maintenance classification.",
        )
    add_docker_findings(findings, docker)
    if not holds_complete:
        add_finding(
            findings,
            "package-holds-unavailable",
            "REVIEW",
            "packages",
            f"held-package evidence unavailable: {holds['stderr'] or holds['stdout'] or 'no result'}",
            "Restore apt-mark visibility before applying package changes.",
        )
    health_complete = dpkg_complete and failed_units_complete
    health_clean = health_complete and dpkg_lines == 0 and failed_units == 0
    add_finding(
        findings,
        "system-health" if health_complete else "system-health-unavailable",
        "KEEP_ACTIVE" if health_clean else "REVIEW",
        "health",
        (
            f"dpkg audit lines={dpkg_lines}; failed systemd units={failed_units}"
            if health_complete
            else f"incomplete evidence: dpkg_complete={dpkg_complete}; failed_units_complete={failed_units_complete}"
        ),
        "No repair indicated." if health_clean else "Investigate or restore the missing evidence before classifying system health.",
    )
    add_finding(
        findings,
        "wsl-vhd-host-space",
        "REVIEW",
        "windows-side",
        "host ext4.vhdx physical size and compaction support were not measured from Linux",
        "Use a separate Windows-side export/shutdown/compaction audit before proposing host-space recovery.",
    )

    counts = {
        name: sum(item["classification"] == name for item in findings)
        for name in ("KEEP_ACTIVE", "REVIEW", "APPROVAL_REQUIRED")
    }
    status = "REVIEW" if counts["REVIEW"] or counts["APPROVAL_REQUIRED"] else "OK"
    executed_commands = [item for item in COMMAND_LEDGER if item.get("executed")]
    blocked_commands = [item for item in COMMAND_LEDGER if item.get("blocked")]
    mutation_commands = [item for item in executed_commands if command_is_mutating(item["command"])]
    network_refresh_commands = [item for item in executed_commands if command_uses_network_refresh(item["command"])]
    audit: dict[str, Any] = {
        "schema_version": 1,
        "version": VERSION,
        "timestamp_utc": datetime.now(timezone.utc).isoformat(),
        "read_only": True,
        "quick": args.quick,
        "output_directory": str(output),
        "safety": {
            "sudo_used": any(Path(item["command"][0]).name.lower() == "sudo" for item in executed_commands),
            "network_refresh_used": bool(network_refresh_commands),
            "mutation_commands_used": mutation_commands,
            "blocked_commands": blocked_commands,
            "command_ledger": executed_commands,
            "mutation_denylist": list(MUTATION_DENYLIST),
        },
        "system": {
            "pretty_name": release.get("PRETTY_NAME", "unknown"),
            "kernel": kernel,
            "wsl_detected": wsl_detected,
            "failed_systemd_units": failed_units,
            "failed_systemd_units_complete": failed_units_complete,
            "kernel_complete": evidence_complete(kernel_result, require_output=True),
            "doctor_records": doctor_records,
            "doctor_complete": doctor_complete,
        },
        "packages": {
            "dpkg_audit_lines": dpkg_lines,
            "dpkg_audit_complete": dpkg_complete,
            "upgradable_count": upgradable_count,
            "held_packages": [line for line in holds["stdout"].splitlines() if line.strip()],
            "held_packages_complete": holds_complete,
            "check_records": package_records,
            "package_check_complete": package_check_complete,
            "metadata_refreshed": False,
        },
        "storage": {
            "disks": disks,
            "apt_cache_bytes": apt_cache["size_bytes"],
            "apt_cache_measurement_complete": apt_cache["complete"],
            "apt_cache_measurement_error": apt_cache["error"],
            "journal_bytes": journal_bytes,
            "journal_raw": journal["stdout"] or journal["stderr"],
            "journal_measurement_complete": journal_complete,
            "developer_caches": developer_caches,
            "home_top_level": home_top,
        },
        "docker": docker,
        "findings": findings,
        "summary": {"status": status, "classification_counts": counts},
        "commands": {
            "linux_doctor": doctor,
            "package_check": package_check,
            "dpkg_audit": dpkg_audit,
            "failed_units": failed_units_result,
        },
    }
    report = render_report(audit)
    reject_symlink_ancestors(audit_path)
    reject_symlink_ancestors(report_path)
    audit_path.write_text(json.dumps(audit, indent=2) + "\n", encoding="utf-8")
    report_path.write_text(report, encoding="utf-8")
    os.chmod(audit_path, 0o600)
    os.chmod(report_path, 0o600)

    result = {
        "status": status,
        "read_only": True,
        "output_directory": str(output),
        "audit_json": str(output / "audit.json"),
        "report_md": str(output / "report.md"),
        "classification_counts": counts,
    }
    if args.format == "json":
        print(json.dumps(result, indent=2))
    else:
        print(f"STATUS {status}")
        print("MODE READ-ONLY")
        print(f"OUTPUT {output}")
        print(f"KEEP_ACTIVE {counts['KEEP_ACTIVE']}")
        print(f"REVIEW {counts['REVIEW']}")
        print(f"APPROVAL_REQUIRED {counts['APPROVAL_REQUIRED']}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
