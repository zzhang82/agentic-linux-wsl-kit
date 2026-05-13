---
name: node-supply-chain-guard
description: Use when an agent wants to install, update, execute, or trust npm/pnpm/yarn/bun packages. Enforces read-only preflight, registry verification, lockfile diffing, install-script review, and human approval.
version: 1.0.0
---

# Skill: node-supply-chain-guard

Use when an agent wants to install, update, execute, or trust npm/pnpm/yarn/bun packages, especially in AI/LLM tooling repos. 

## Usage

This skill is an **enforcement point**. It prevents agents from running raw package mutation commands and forces a secure workflow.

### Triggering Commands

If an agent attempts to run any of the following:
- `npm install`, `npm update`, `npm exec`, `npx`
- `pnpm add`, `pnpm update`, `pnpm dlx`
- `yarn add`, `yarn install`
- `bun add`, `bunx`

**Stop and hand off to this skill.**

### Secure Workflow

1. **Pre-flight**: Run `scripts/node-supply-chain-guard.sh --preinstall`.
2. **Review**: Inspect `package.json` lifecycle scripts and registry configuration.
3. **Approval**: Present the intended command and risk summary to the human.
4. **Execution**: If approved, run the command with `--ignore-scripts` in a stripped environment.
5. **Post-flight**: Run `scripts/node-supply-chain-guard.sh --postinstall-scan`.

## Policies

- **Deny-by-Default**: No `postinstall` or native build scripts run without explicit review.
- **Registry Lock**: Only the official `registry.npmjs.org` is allowed unless overridden by project policy.
- **No Secrets**: Package operations must run in an environment stripped of LLM API keys, GitHub tokens, and cloud credentials.
- **Deterministic Installs**: Prefer `npm ci` or `pnpm install --frozen-lockfile` to ensure consistency.

## Enforcement Tools

- `scripts/node-supply-chain-guard.sh`: The main driver.
- `scripts/safe-npm.sh`: A wrapper for `npm` that routes requests through the guard.
