# Project Model Routing Policy

## Purpose

Build and validate the open-source Agentic Linux WSL Kit without leaking private data.

## Routes

| Task type | Preferred model / agent | Role |
|---|---|---|
| Goal ownership | `local/gpt-5.5` | Final decisions, patches, validation |
| Lightweight search/research | `local/gemini-3-flash` | Fast evidence gathering |
| Image generation | `local/gpt-image-2` | README architecture illustration only |
| Code review | `local/codex-auto-review`; fallback `local/gpt-5.5` | Diff risk review |

## Rules

- Treat the repository as public/open-source.
- Never include API keys, personal credentials, private hostnames, or secret contents.
- Prefer read-only/default-safe workflows.
- WSL unregister/import/export examples must require explicit human confirmation.
- Validate scripts with syntax checks and non-destructive dry-run style tests.
