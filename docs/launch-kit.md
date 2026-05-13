# Aegis Skills launch kit

Use this file to promote Aegis Skills ethically and consistently.

## Goal

Get the right users to try, star, fork, and contribute to Aegis Skills:

- LLM coding-agent users
- WSL power users
- DevSecOps engineers
- open-source maintainers
- security-minded Node/npm users
- people building local AI automation workflows

## Core positioning

```text
Aegis Skills is not another coding agent. It is a safe-by-default automation layer that gives existing agents and humans guardrails for Linux/WSL operations.
```

## One-line pitch

```text
Aegis Skills helps AI coding agents work safely inside Linux/WSL: diagnose first, block risky package commands, isolate approved installs, and produce audit-ready evidence.
```

## Short pitch

```text
Aegis Skills is a small open-source toolkit of SKILL.md playbooks, shell scripts, wrappers, and SOPs for safer Linux/WSL agent workflows.

It adds read-only diagnostics, safe package-update workflows, recurring security audits, and an active package-manager guard that intercepts npm/pnpm/yarn/bun/npx commands before they can run with your real secrets.
```

## Best launch channels

### 1. Hacker News

Post type:

```text
Show HN: Aegis Skills - safe-by-default Linux/WSL workflows for coding agents
```

Post body:

```text
I built Aegis Skills after noticing that coding agents can run package installs and system commands with too much trust in the local environment.

It is not an agent. It is a set of SKILL.md playbooks, scripts, wrappers, and SOPs for safer Linux/WSL workflows:

- read-only Linux/WSL diagnostics
- safe package/security update flow
- rollback-aware WSL migration workflow
- recurring security audits with summary.json output
- npm/pnpm/yarn/bun/npx wrappers that block risky package operations
- a supply-chain guard that runs approved installs with env -i, temp HOME, restricted PATH, and postinstall scans

The goal is to make agent workflows evidence-first and safe-by-default rather than fully autonomous.

Repo: https://github.com/zzhang82/agentic-linux-wsl-kit
```

Comment follow-up:

```text
The part I care most about is the active defense layer: raw npm/pnpm/yarn/bun/npx operations are intercepted and routed through a guard. The guard checks registry/lockfile/lifecycle scripts, requires approval, then runs approved installs in an isolated environment.
```

### 2. Reddit

Suggested communities:

```text
r/LocalLLaMA
r/selfhosted
r/devops
r/linux
r/bash
r/node
r/cybersecurity
r/opensource
```

Reddit title options:

```text
I built Aegis Skills: safe-by-default Linux/WSL workflows for AI coding agents
```

```text
Open-source toolkit to stop coding agents from running unsafe npm installs in WSL
```

Reddit body:

```text
I built Aegis Skills as a small open-source toolkit for people using coding agents inside Linux/WSL.

The idea: agents should diagnose first, preview risky changes, and never run package-manager commands with your real environment/secrets unless the operation is reviewed and guarded.

Current features:

- linux-doctor: read-only WSL/Linux diagnostics
- package-security-update: preview/apply package update flow
- wsl-security-routine: daily/weekly/monthly/preflight audits with summary.json
- node-supply-chain-guard: blocks raw npm/pnpm/yarn/bun/npx operations and runs approved installs with env -i, temp HOME, restricted PATH, and postinstall scans

I would appreciate feedback from people running local agents or WSL-based dev environments.

Repo: https://github.com/zzhang82/agentic-linux-wsl-kit
```

### 3. LinkedIn

```text
I just open-sourced Aegis Skills: a safe-by-default automation layer for Linux/WSL and LLM coding-agent workflows.

It is not another agent. It is a set of reusable skills, scripts, wrappers, and SOPs that help existing agents work more safely:

- diagnose Linux/WSL health before acting
- preview risky package/security updates
- run recurring security audits with machine-readable summaries
- intercept npm/pnpm/yarn/bun/npx commands
- execute approved package installs in an isolated environment

The project is built around a simple principle: agents can move fast, but risky work should be evidence-first, guarded, and auditable.

Repo: https://github.com/zzhang82/agentic-linux-wsl-kit
```

### 4. X / Twitter

Short post:

```text
I open-sourced Aegis Skills: safe-by-default Linux/WSL automation skills for AI coding agents.

It adds read-only diagnostics, security audits, package-update workflows, and an active guard that blocks risky npm/pnpm/yarn/bun/npx commands before they touch your real environment.

https://github.com/zzhang82/agentic-linux-wsl-kit
```

Thread:

```text
1/ I built Aegis Skills for a problem I kept seeing: coding agents can run package installs and system commands with too much trust.

2/ It is not an agent. It is a skill-and-script layer for Linux/WSL workflows: diagnostics, safe updates, security audits, and package-manager guardrails.

3/ The active defense layer intercepts npm/pnpm/yarn/bun/npx and routes risky commands through a supply-chain guard.

4/ Approved installs run with env -i, a temporary HOME, restricted PATH, ignored scripts, and postinstall scans.

5/ Goal: make local agent workflows evidence-first, safe-by-default, and audit-ready.

Repo: https://github.com/zzhang82/agentic-linux-wsl-kit
```

### 5. Product Hunt

Tagline:

```text
Safe-by-default Linux/WSL workflows for AI coding agents
```

Description:

```text
Aegis Skills is an open-source skill-and-script toolkit that helps AI coding agents work safely inside Linux/WSL. It adds read-only diagnostics, security audits, package update workflows, and an active guard that blocks risky package-manager commands before they can run with your real secrets.
```

Maker comment:

```text
I built Aegis Skills because local coding agents are powerful but often operate with too much trust. The project is not another agent. It is a safety layer for existing agents and humans: skills, deterministic scripts, command wrappers, and SOPs that keep Linux/WSL workflows evidence-first and guarded by default.
```

## GitHub About section

Description:

```text
Secure automation skills for Linux/WSL agents: diagnostics, security audits, safe updates, and active package-manager defense.
```

Website:

```text
https://github.com/zzhang82/agentic-linux-wsl-kit
```

Topics:

```text
llm-agents
coding-agents
agentic-ai
ai-safety
devsecops
supply-chain-security
npm-security
wsl
linux
ubuntu
automation
security-tools
skills
shell-script
```

## First week promotion plan

### Day 1

- Update GitHub About description and topics.
- Create a GitHub release for MVP5.
- Post on X/LinkedIn.
- Ask 5-10 trusted technical friends for feedback, not just stars.

### Day 2

- Submit Show HN.
- Stay active in comments for the first 2-3 hours.
- Answer technical questions honestly.

### Day 3

- Post to one relevant subreddit with a specific angle.
- Do not cross-post everywhere at once.

### Day 4

- Write a short blog post: `Why coding agents need package-manager guardrails`.
- Link back to the repo.

### Day 5

- Open 3 good-first-issues:
  - containerized package quarantine
  - richer lockfile diffing
  - install script risk classifier

### Day 6-7

- Package a v0.1.0 release.
- Add short demo GIF/video if possible.
- Share lessons learned.

## What not to do

- Do not buy stars.
- Do not spam every subreddit.
- Do not claim the project solves all supply-chain risk.
- Do not call it an agent.
- Do not overpromise fully autonomous security.

## Good star CTA

Use this lightly:

```text
If Aegis Skills helps your agent workflow feel safer, a GitHub star helps others find it.
```

## Maintainer reply templates

### If someone says this is too paranoid

```text
That is fair for low-risk projects. Aegis Skills is aimed at workflows where coding agents can run local commands and where package-manager operations may inherit real tokens, SSH agent access, or project secrets. The guardrails are intentionally conservative and can be adopted piece by piece.
```

### If someone asks why not Docker-only

```text
Containerized quarantine is the next milestone. The current MVP focuses on WSL-friendly guardrails that work even when users are not running every agent task inside Docker.
```

### If someone asks whether it replaces security tools

```text
No. Aegis Skills orchestrates existing tools and adds workflow guardrails. It uses tools like Gitleaks, Trivy, Grype, TruffleHog, and Lynis where available, but the main value is safer agent workflow structure.
```
