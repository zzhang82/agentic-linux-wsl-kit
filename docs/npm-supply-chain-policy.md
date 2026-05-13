# npm Supply Chain Policy

This policy defines the security requirements for Node.js/npm package management in this repository.

## Registry Policy

- **Allowed**: `https://registry.npmjs.org/`
- **Restricted**: Any private, scoped, or proxy registry requires explicit project-level approval.
- **Verification**: Registry signatures must be verified where possible (`npm audit signatures`).

## Package Installation Policy

- **Clean Installs**: Always use `npm ci` for CI/CD and agent-led environments.
- **Ignore Scripts**: Automated installations MUST use `--ignore-scripts`.
- **Lifecycle Scripts**: Any `preinstall`, `install`, or `postinstall` script found in a dependency must be manually reviewed and approved before execution.
- **Lockfiles**: Lockfiles (`package-lock.json`, `pnpm-lock.yaml`) must be checked into version control. No installation is permitted without a lockfile.

## Vulnerability Policy

- **Critical/High**: No Critical or High severity vulnerabilities are allowed in production dependencies.
- **Audit**: `npm audit` must be run as part of the `wsl-security-routine`.

## Environment Isolation

- Package managers must run in an environment stripped of the following variables:
  - `*_API_KEY`
  - `*_TOKEN`
  - `AWS_*`
  - `GOOGLE_*`
  - `SSH_AUTH_SOCK`

## Tooling

- **Enforcement**: `scripts/node-supply-chain-guard.sh`
- **Scanning**: `gitleaks`, `trivy`, `grype`
