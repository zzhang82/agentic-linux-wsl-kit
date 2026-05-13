#!/usr/bin/env python3
import os
import sys
import json
from pathlib import Path

def summarize(run_dir):
    run_path = Path(run_dir)
    summary = {
        "status": "OK",
        "findings": [],
        "run_info": {
            "directory": str(run_path),
            "mode": "unknown",
            "timestamp": "unknown"
        }
    }

    # 0. Load manifest
    manifest_file = run_path / "manifest.json"
    if manifest_file.exists():
        with open(manifest_file, "r") as f:
            manifest = json.load(f)
            summary["run_info"].update({
                "mode": manifest.get("mode", "unknown"),
                "timestamp": manifest.get("timestamp_utc", "unknown"),
                "project_path": manifest.get("project_path", "unknown")
            })

    # 1. Parse linux-doctor.ndjson
    doctor_file = run_path / "linux-doctor.ndjson"
    if doctor_file.exists():
        with open(doctor_file, "r") as f:
            for line in f:
                try:
                    entry = json.loads(line)
                    if entry.get("level") in ["WARN", "FAIL"]:
                        summary["findings"].append({
                            "source": "linux-doctor",
                            "level": entry["level"],
                            "area": entry["area"],
                            "message": entry["message"]
                        })
                except json.JSONDecodeError:
                    continue

    # 2. Parse package-check.ndjson
    package_file = run_path / "package-check.ndjson"
    if package_file.exists():
        with open(package_file, "r") as f:
            for line in f:
                try:
                    entry = json.loads(line)
                    if "upgradable packages:" in entry.get("message", ""):
                        count_str = entry["message"].split(":")[1].strip()
                        count = int(count_str)
                        if count > 0:
                            summary["findings"].append({
                                "source": "package-check",
                                "level": "WARN",
                                "area": "apt",
                                "message": f"{count} upgradable packages found"
                            })
                    elif entry.get("level") in ["WARN", "FAIL"]:
                        summary["findings"].append({
                            "source": "package-check",
                            "level": entry["level"],
                            "area": entry["area"],
                            "message": entry["message"]
                        })
                except (json.JSONDecodeError, ValueError, IndexError):
                    continue

    # 2b. Parse git-status.txt
    git_status_file = run_path / "git-status.txt"
    if git_status_file.exists():
        with open(git_status_file, "r") as f:
            lines = f.readlines()
            if lines:
                summary["findings"].append({
                    "source": "git",
                    "level": "INFO",
                    "area": "preflight",
                    "message": f"Active repo status: {lines[0].strip()}"
                })

    # 3. Check for gitleaks findings
    for gitleaks_json in run_path.glob("gitleaks-*.json"):
        try:
            with open(gitleaks_json, "r") as f:
                leaks = json.load(f)
                if leaks:
                    summary["findings"].append({
                        "source": "gitleaks",
                        "level": "FAIL",
                        "area": "secrets",
                        "message": f"{len(leaks)} potential secrets detected in {gitleaks_json.name}"
                    })
        except (json.JSONDecodeError, ValueError):
            continue

    # 4. Check for lynis findings
    lynis_file = run_path / "lynis.txt"
    if lynis_file.exists():
        with open(lynis_file, "r") as f:
            content = f.read()
            if "sudo without prompt is unavailable" in content:
                summary["findings"].append({
                    "source": "lynis",
                    "level": "INFO",
                    "area": "hardening",
                    "message": "Lynis audit skipped: sudo without prompt is unavailable"
                })
            elif "warning" in content.lower() or "suggestion" in content.lower():
                summary["findings"].append({
                    "source": "lynis",
                    "level": "INFO",
                    "area": "hardening",
                    "message": "Lynis completed with warnings/suggestions. See lynis.txt for details."
                })

    # 5. Check for trivy findings
    trivy_json = run_path / "trivy-fs.json"
    if trivy_json.exists():
        try:
            with open(trivy_json, "r") as f:
                data = json.load(f)
                vulns = []
                for result in data.get("Results", []):
                    for vuln in result.get("Vulnerabilities", []):
                        if vuln.get("Severity") in ["CRITICAL", "HIGH"]:
                            vulns.append(vuln)
                if vulns:
                    summary["findings"].append({
                        "source": "trivy",
                        "level": "WARN",
                        "area": "vulnerability",
                        "message": f"{len(vulns)} Critical or High vulnerabilities found by Trivy"
                    })
        except (json.JSONDecodeError, ValueError):
            pass

    # 6. Check for grype findings
    grype_json = run_path / "grype.json"
    if grype_json.exists():
        try:
            with open(grype_json, "r") as f:
                data = json.load(f)
                vulns = []
                for match in data.get("matches", []):
                    severity = match.get("vulnerability", {}).get("severity")
                    if severity in ["Critical", "High"]:
                        vulns.append(match)
                if vulns:
                    summary["findings"].append({
                        "source": "grype",
                        "level": "WARN",
                        "area": "vulnerability",
                        "message": f"{len(vulns)} Critical or High vulnerabilities found by Grype"
                    })
        except (json.JSONDecodeError, ValueError):
            pass

    # 7. Check for trufflehog findings
    trufflehog_json = run_path / "trufflehog.json"
    if trufflehog_json.exists():
        try:
            leaks_count = 0
            with open(trufflehog_json, "r") as f:
                for line in f:
                    if line.strip():
                        leaks_count += 1
            if leaks_count > 0:
                summary["findings"].append({
                    "source": "trufflehog",
                    "level": "FAIL",
                    "area": "secrets",
                    "message": f"{leaks_count} verified secret findings detected by TruffleHog"
                })
        except Exception:
            pass

    # Determine overall status
    if any(f["level"] == "FAIL" for f in summary["findings"]):
        summary["status"] = "FAIL"
    elif any(f["level"] == "WARN" for f in summary["findings"]):
        summary["status"] = "WARN"

    return summary

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: wsl-security-summarize.py <run_dir>")
        sys.exit(1)
    
    run_dir = sys.argv[1]
    result = summarize(run_dir)
    print(json.dumps(result, indent=2))
