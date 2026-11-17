# ai-skills

Reusable skills for Claude Code (and other agents that read `SKILL.md` files). Each skill is a folder under [`skills/`](skills/) with a `SKILL.md` that says when to use it and what to do.

## Skills

**Safety**

| Skill | Use it when |
|---|---|
| [agent-guardrails](skills/agent-guardrails/SKILL.md) | Any agent work: outside content is untrusted, least-privilege tokens and permissions, what needs explicit approval, protecting secrets and private context. |
| [credentials-handling](skills/credentials-handling/SKILL.md) | Code needs a password, API key, token, or connection string. Secrets go in a git-ignored `config.local.json` (or env vars), read through one accessor. |
| [public-repo-hygiene](skills/public-repo-hygiene/SKILL.md) | Committing, pushing, or publishing anything. Keeps IPs, hostnames, paths, emails and network layout out of public repos (blocks) and flags them in private ones (warns). Includes a scanner. |
| [homelab-changes](skills/homelab-changes/SKILL.md) | Changing any live self-hosted system. Read-only by default; backup, dry run, rollback plan and approval for every change. |

**Homelab**

| Skill | Use it when |
|---|---|
| [arr-media-cleanup](skills/arr-media-cleanup/SKILL.md) | Freeing space on a Radarr/Sonarr + Plex server: delete through the APIs so nothing re-downloads, record state for restore, Plex watched checks, plan and dry run, untracked folders and download leftovers. |
| [synology-ssh-access](skills/synology-ssh-access/SKILL.md) | Setting up or using SSH on a Synology NAS for an agent or service account: administrators-group rule, key setup and permissions, custom ports, limited sudo, Windows quirks. |

**Development**

| Skill | Use it when |
|---|---|
| [git-workflow](skills/git-workflow/SKILL.md) | Branching, committing, pushing, opening PRs. `main` is protected; squash-merged PRs that pass CI. |
| [new-repo-setup](skills/new-repo-setup/SKILL.md) | Creating a repo or bringing one up to standard: protection, required checks, security settings, baseline files. |
| [supply-chain](skills/supply-chain/SKILL.md) | Adding or updating dependencies, images, Actions, tools, or MCP servers. Pin versions, Actions to SHAs, no `curl \| sh`. |
| [docker-practices](skills/docker-practices/SKILL.md) | Writing Dockerfiles or compose files, or running containers. |
| [writing-skills](skills/writing-skills/SKILL.md) | Adding or editing a skill in this repo. |

This repo is public, so skills here stay generic. Details about a specific environment belong in a private companion repo.

## Using these skills

**All projects (personal skills):** copy or link each skill folder into `~/.claude/skills/`. A directory junction keeps it in sync with this repo on Windows:

```powershell
New-Item -ItemType Junction -Path "$env:USERPROFILE\.claude\skills\credentials-handling" -Target "c:\code\ai-skills\skills\credentials-handling"
```

**One project:** copy the skill folders into that project's `.claude/skills/`.

**As a plugin:** the repo includes [`.claude-plugin/plugin.json`](.claude-plugin/plugin.json), so it can be loaded as a Claude Code plugin.

## Global instructions (`CLAUDE.md`)

[`claude/CLAUDE.md`](claude/CLAUDE.md) holds short defaults that apply to every project (for example, docstrings on all Python functions). Rules that need steps or examples belong in a skill instead. Link it to `~/.claude/CLAUDE.md` so edits here take effect everywhere (a file symlink needs Developer Mode or an elevated shell on Windows):

```powershell
New-Item -ItemType SymbolicLink -Path "$env:USERPROFILE\.claude\CLAUDE.md" -Target "c:\code\ai-skills-main\claude\CLAUDE.md"
```

Point the link at a checkout that stays on `main`, so a feature branch never changes what every session loads.

## Contributing

`main` is protected: work on a branch and open a pull request. See [writing-skills](skills/writing-skills/SKILL.md), and run the check before you push:

```bash
bash scripts/validate-skills.sh
```

CI runs the same check plus a [gitleaks](https://github.com/gitleaks/gitleaks) secret scan on every PR.
