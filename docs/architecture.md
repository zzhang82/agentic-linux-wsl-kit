# Architecture

Agentic Linux WSL Kit separates instruction, action, and validation.

```text
SKILL.md
  describes when/how an agent should act
      |
      v
scripts/
  deterministic shell/PowerShell helpers
      |
      v
evidence
  command output, status summaries, warnings
      |
      v
human/agent decision
  apply fix, stop, or gather more evidence
```

## Design principles

- Skills are playbooks, not autonomous daemons.
- Scripts should be safe to inspect and easy to run manually.
- Read-only diagnostics should be the default.
- Update and migration scripts must distinguish preview from apply.
- WSL destructive actions require explicit human confirmation.

## Module dependency map

```text
linux-doctor
  ^        ^
  |        |
  |        +-- wsl-version-migration validates before/after
  |
  +----------- package-security-update validates before/after
```
