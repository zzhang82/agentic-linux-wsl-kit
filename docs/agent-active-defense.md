# Agent Active Defense

This document describes the "Active Defense" strategy for Agentic Linux WSL environments. 

## The Problem

LLM coding agents have broad file and command execution permissions. This creates a significant supply-chain risk if an agent is tricked into installing or executing malicious code via package managers (`npm`, `pnpm`, etc.).

## The Strategy

Instead of relying on the agent to "be secure," we enforce security via **interception** and **policy gating**.

### 1. Interception Layer

We provide shell wrappers (`scripts/safe-npm.sh`, etc.) that intercept dangerous commands. These wrappers block direct execution and redirect the agent to the security guard.

### 2. Policy Gating (The Guard)

The `scripts/node-supply-chain-guard.sh` script acts as the enforcement brain. It:
- Inspects project configuration for non-standard registries.
- Reviews `package.json` for hidden lifecycle scripts.
- Suggests safe alternatives (like `npm ci --ignore-scripts`).
- Forces a stripped environment for package operations to prevent secret exfiltration.

### 3. Isolated Execution

Package operations should ideally be run in a disposable container (Docker) or a strictly limited subshell. 

### 4. Post-Install Validation

After any dependency change, a mandatory security scan is performed on the `node_modules` directory using Gitleaks and Trivy.

## Workflow for Agents

1. **Pre-flight**: Agent runs `wsl-security-check --preflight`.
2. **Dependency Request**: Agent uses `node-supply-chain-guard --request "..."`.
3. **Review & Approve**: Human reviews the guard's output and safe command suggestion.
4. **Isolated Install**: Approved command runs in a stripped environment.
5. **Post-Scan**: Agent runs `node-supply-chain-guard --postinstall-scan`.

## Key Safety Rules

- **No Secrets**: Never expose `OPENAI_API_KEY` or `GITHUB_TOKEN` to package manager processes.
- **No Scripts**: Always use `--ignore-scripts` during automated installs.
- **Deterministic**: Always prefer `npm ci` or frozen lockfiles.
- **Evidence-First**: Every operation must produce a log in `~/.local/state/wsl-security/`.
