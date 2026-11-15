---
name: new-repo-setup
description: Use when the user wants a new git repository or GitHub repo created, cloned, or initialized. Covers where repos live (c:/code), creating it with gh, protecting main so it requires pull requests, and the baseline files every repo gets (.gitignore with secret patterns, .gitattributes, .editorconfig, PR template, README).
---

# New repository setup

## 1. Location

Repos live under **`c:/code/<repo-name>`**, never next to whatever folder is currently open.

## 2. Create and clone

```powershell
Set-Location c:\code
gh repo create <repo-name> --public --add-readme --description "<description>" --clone
Set-Location <repo-name>
```

- Ask whether it should be `--public` or `--private` if the user hasn't said.
- Existing local folder instead: `git init -b main`, then `gh repo create <repo-name> --source . --push`.

## 3. Protect main

Apply the ruleset in [assets/protect-main-ruleset.json](assets/protect-main-ruleset.json): changes to the default branch require a pull request (0 approvals, so the user can merge their own PRs), and force-pushes and branch deletion are blocked.

```bash
gh api -X POST repos/<owner>/<repo-name>/rulesets \
  --input <path-to>/protect-main-ruleset.json \
  --jq '"id=\(.id) enforcement=\(.enforcement) rules=\([.rules[].type]|join(","))"'
```

Get `<owner>` from `gh api user --jq .login`. Rulesets on private repos need a paid GitHub plan; if the call fails with a plan error, tell the user rather than retrying.

Verify: `gh api repos/<owner>/<repo-name>/rulesets --jq '.[].name'`.

## 4. Baseline files (on a branch, via PR)

Because main is now protected, add these on a branch such as `chore/repo-setup` and open a PR (see the `git-workflow` skill):

- **`.gitignore`** — start from the language's standard ignores, and **always** include the secret patterns from the `credentials-handling` skill (`config.local.json`, `.env`, `.env.*`, `!.env.example`, `*.pem`, `*.pfx`, `*.key`, `secrets/`).
- **`.gitattributes`** — `* text=auto eol=lf`, plus `*.ps1`/`*.bat`/`*.cmd` as `eol=crlf`, and binary types marked `binary`.
- **`.editorconfig`** — UTF-8, final newline, trim trailing whitespace, 2-space indent default (4 for languages that expect it).
- **`.github/pull_request_template.md`** — Summary / Why / Testing / Checklist (including "no secrets committed").
- **`README.md`** — what it is, how to set it up, including "copy `config.example.json` to `config.local.json`" if the project has secrets.

The `ai-skills` repo has working copies of all of these to copy from.

## 5. Report back

Tell the user the repo URL, the local path, what protection is on, and that VS Code can be pointed at it with `code c:\code\<repo-name>` (you can't switch their window yourself).
