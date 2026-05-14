# Aegis Trigger System

Aegis Skills operates as a **safety harness** around Linux/WSL and agent workflows. Instead of relying on manual execution, Aegis uses a unified trigger layer to catch risky boundaries automatically.

## The Four Layers of Defense

### 1. Skill Triggers (Instruction Layer)
LLM Agents use `SKILL.md` files to understand how to perform tasks safely.
- **Trigger**: Agent recognizes a task matching a skill description.
- **Action**: Agent follows the SOP, uses specialized tools, and produces evidence.

### 2. Command Triggers (Interception Layer)
Wrappers intercept risky package manager commands (`npm`, `pnpm`, `yarn`, `bun`, `npx`).
- **Trigger**: Any execution of the raw command.
- **Action**: Routed through `scripts/aegis-trigger.sh --event package-command`, which calls the supply-chain guard.

### 3. Git Triggers (Workflow Layer)
Local git hooks enforce policy at commit, push, and merge boundaries.
- **Trigger**: `git commit`, `git push`, or `git merge/pull`.
- **Action**:
    - **Pre-commit**: Secret scanning (Gitleaks).
    - **Pre-push**: Health check, security preflight, and smoke tests.
    - **Post-merge**: Lockfile change detection and security review.

### 4. Time Triggers (Persistence Layer)
Systemd user timers run recurring security audits.
- **Trigger**: Daily, weekly, or monthly intervals.
- **Action**: Full security checks and inventory reports.

---

## Central Dispatcher: `aegis-trigger.sh`

All automated triggers (except Skill triggers) flow through `scripts/aegis-trigger.sh`. This provides a single point of policy enforcement and logging.

### Usage

```bash
# Manual preflight
bash scripts/aegis-trigger.sh --event agent-start --project .

# Intercepted command
bash scripts/aegis-trigger.sh --event package-command --project . -- "npm install axios"

# Scheduled check
bash scripts/aegis-trigger.sh --event weekly --project .
```

## Setup

Use the installer to activate the trigger layers:

```bash
# Install package wrappers and git hooks
bash scripts/install-aegis-triggers.sh --all
```

---

## Safety Policy: Auto vs Gated

| Action | Automation |
| :--- | :--- |
| **Scans / Diagnostics** | **Automatic** |
| **Evidence Generation** | **Automatic** |
| **Lockfile Review** | **Automatic** |
| **Package Installs** | **Gated (Requires Approval)** |
| **System Updates** | **Gated (Requires Approval)** |
| **Destructive Actions** | **Never Automatic** |
