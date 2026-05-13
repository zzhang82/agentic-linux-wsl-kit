# Aegis Skills architecture

Aegis Skills separates instruction, action, enforcement, and validation.

It is not an autonomous agent. It is a set of skills and scripts that make existing agent workflows safer and easier to audit.

```text
SKILL.md playbooks
  describe when and how an agent should act
      |
      v
scripts/
  deterministic shell and PowerShell helpers
      |
      v
wrappers/
  intercept risky package-manager commands
      |
      v
guards/
  run approved actions in restricted environments
      |
      v
evidence
  logs, status summaries, warnings, summary.json
      |
      v
human or automation decision
  apply fix, stop, or gather more evidence
```

## Design principles

- Skills are playbooks, not autonomous daemons.
- Scripts should be safe to inspect and easy to run manually.
- Read-only diagnostics should be the default.
- Package installs should be intercepted and guard-owned.
- Update and migration scripts must distinguish preview from apply.
- WSL destructive actions require explicit human confirmation.
- Every risky workflow should produce evidence before and after.

## Module dependency map

```text
linux-doctor
  ^        ^          ^
  |        |          |
  |        |          +-- wsl-security-routine uses baseline evidence
  |        |
  |        +------------- wsl-version-migration validates before/after
  |
  +---------------------- package-security-update validates before/after

safe-* wrappers
  -> node-supply-chain-guard
  -> postinstall scan
  -> wsl-security-routine evidence when needed
```
