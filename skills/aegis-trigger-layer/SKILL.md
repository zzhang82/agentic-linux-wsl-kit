# aegis-trigger-layer

Unified dispatcher for safety events in Linux/WSL environments.

## Goal
Enforce safety policies automatically by intercepting risky actions and routing them through Aegis guards.

## Triggers
- **Agent Start**: Before beginning any new task or session.
- **Git Events**: Pre-commit, pre-push, and post-merge.
- **Package Commands**: When running `npm`, `pnpm`, `yarn`, `bun`, or `npx`.
- **Schedules**: Daily or weekly security audits.

## Instructions

### 1. Preflight a Session
Always run a preflight before starting work in a new repository or session.
```bash
bash scripts/aegis-trigger.sh --event agent-start --project .
```

### 2. Handle Intercepted Commands
If a command like `npm install` is blocked:
1. Review the proposed safe command provided by the dispatcher.
2. If it looks correct, execute it using the approved flag:
```bash
bash scripts/node-supply-chain-guard.sh --execute-approved <approved-command> --project .
```

### 3. Setup Local Enforcement
Install the safety harness for the current user and repository.
```bash
bash scripts/install-aegis-triggers.sh --all
```

## Validation
- Check `summary.json` after events.
- Verify that `npm` commands are blocked when raw execution is attempted.
- Ensure Gitleaks runs automatically on `git commit`.

## Stop Conditions
- If a security check finds a high-risk vulnerability (secrets exposed, malicious package).
- If the trigger layer blocks an action and no safe alternative is obvious.
