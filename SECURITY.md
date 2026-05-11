# Security Policy

## Reporting vulnerabilities

Please open a GitHub security advisory or issue with enough detail to reproduce the problem. Do not include real secrets in reports.

## Secret handling policy

- Scripts must not print secret file contents.
- Examples must use placeholders.
- Repo content must not include real API keys, tokens, private keys, or credential files.

## Destructive action policy

- WSL `--unregister` is never automated by this kit.
- Update scripts require `--apply` before changing packages.
- Migration workflows require validated rollback before cutover.
