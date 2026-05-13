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
            "mode": run_path.name.split("-")[0]
        }
    }

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

    # 3. Check for gitleaks findings
    for gitleaks_file in run_path.glob("gitleaks-*.txt"):
        if gitleaks_file.exists() and gitleaks_file.stat().st_size > 0:
            with open(gitleaks_file, "r") as f:
                content = f.read()
                if "leaks found" in content.lower() or "finding" in content.lower():
                    summary["findings"].append({
                        "source": "gitleaks",
                        "level": "FAIL",
                        "area": "secrets",
                        "message": f"Potential secrets detected in {gitleaks_file.name}"
                    })

    # 4. Check for lynis findings
    lynis_file = run_path / "lynis.txt"
    if lynis_file.exists():
        with open(lynis_file, "r") as f:
            content = f.read()
            if "warning" in content.lower() or "suggestion" in content.lower():
                summary["findings"].append({
                    "source": "lynis",
                    "level": "INFO",
                    "area": "hardening",
                    "message": "Lynis completed with warnings/suggestions. See lynis.txt for details."
                })

    # 5. Check for trivy findings
    trivy_file = run_path / "trivy-fs.txt"
    if trivy_file.exists():
        with open(trivy_file, "r") as f:
            content = f.read()
            if "CRITICAL" in content or "HIGH" in content:
                summary["findings"].append({
                    "source": "trivy",
                    "level": "WARN",
                    "area": "vulnerability",
                    "message": "Critical or High vulnerabilities found by Trivy"
                })

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
