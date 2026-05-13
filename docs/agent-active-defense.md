# Aegis Skills active defense

This document describes the active defense strategy used by Aegis Skills for agent-led package operations.

Aegis Skills is not an agent. It provides skills, wrappers, scripts, and policies that existing agents or humans can run.

## The problem

LLM coding agents can have broad file and command execution permissions. That creates supply-chain risk if an agent is tricked into installing or executing malicious code through package managers such as `npm`, `pnpm`, `yarn`, `bun`, or `npx`.

The dangerous pattern is simple:

```text
agent receives task -> agent runs package install -> lifecycle script executes -> secrets or source code are exposed
```

## The strategy

Do not rely on the agent to remember every security rule. Enforce security with **interception** and **policy gating**.

### 1. Interception layer

Shell wrappers intercept dangerous commands:

```text
safe-npm.sh
safe-npx.sh
safe-pnpm.sh
safe-yarn.sh
safe-bun.sh
```

These wrappers block direct execution and redirect the agent to `scripts/node-supply-chain-guard.sh`.

### 2. Policy gating

`node-supply-chain-guard.sh` is the enforcement point. It:

- checks project registry configuration;
- checks lockfile presence;
- reviews lifecycle scripts;
- proposes guard-owned execution commands;
- runs approved installs in an isolated environment;
- runs post-install scanning.

### 3. Isolated execution

Approved package operations run with:

```text
env -i
temporary HOME
restricted PATH
npm/pnpm config redirected into temp HOME
--ignore-scripts / frozen lockfile behavior
```

This prevents package-manager operations from casually inheriting API keys, GitHub tokens, cloud credentials, SSH agent sockets, or the user's real `.npmrc`.

### 4. Post-install validation

After a dependency change, scan `node_modules` with available tools such as Gitleaks and Trivy.

## Workflow for agents

1. Run a security preflight.
2. Request the package operation through the guard.
3. Present the guard output to the human.
4. Execute only the guard-owned approved command.
5. Run post-install scanning.
6. Report findings and next steps.

```bash
bash scripts/wsl-security-check.sh --preflight --project .
bash scripts/node-supply-chain-guard.sh --request "npm install <package>" --project .
bash scripts/node-supply-chain-guard.sh --execute-approved npm-ci --project .
bash scripts/node-supply-chain-guard.sh --postinstall-scan --project .
```

## Key safety rules

- Do not expose API keys or tokens to package-manager processes.
- Do not run raw `npm install`, `pnpm add`, `npx`, `bunx`, or similar commands directly.
- Use `--ignore-scripts` during automated installs.
- Prefer deterministic installs such as `npm ci` or frozen lockfiles.
- Treat lifecycle scripts as executable code that needs review.
- Produce evidence before and after risky work.
