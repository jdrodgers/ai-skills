# ai-skills

Reusable skills for Claude Code (and other agents that read `SKILL.md` files). Each skill is a folder under [`skills/`](skills/) with a `SKILL.md` that says when to use it and what to do.

## Skills

| Skill | Use it when |
|---|---|
| [credentials-handling](skills/credentials-handling/SKILL.md) | Code needs a password, API key, token, or connection string. Secrets go in a git-ignored `config.local.json` (or env vars), read through one accessor. |
| [git-workflow](skills/git-workflow/SKILL.md) | Branching, committing, pushing, opening PRs. `main` is protected, so everything goes through a pull request. |
| [new-repo-setup](skills/new-repo-setup/SKILL.md) | Creating a new repo: lives in `c:/code`, created with `gh`, main protected, baseline files added. |
| [writing-skills](skills/writing-skills/SKILL.md) | Adding or editing a skill in this repo. |

## Using these skills

**All projects (personal skills):** copy or link each skill folder into `~/.claude/skills/`. A directory junction keeps it in sync with this repo on Windows:

```powershell
New-Item -ItemType Junction -Path "$env:USERPROFILE\.claude\skills\credentials-handling" -Target "c:\code\ai-skills\skills\credentials-handling"
```

**One project:** copy the skill folders into that project's `.claude/skills/`.

**As a plugin:** the repo includes [`.claude-plugin/plugin.json`](.claude-plugin/plugin.json), so it can be loaded as a Claude Code plugin.

## Contributing

`main` is protected: work on a branch and open a pull request. See [writing-skills](skills/writing-skills/SKILL.md), and run the check before you push:

```bash
bash scripts/validate-skills.sh
```

CI runs the same check plus a [gitleaks](https://github.com/gitleaks/gitleaks) secret scan on every PR.
