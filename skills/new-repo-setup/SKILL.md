---
name: new-repo-setup
description: Use when the user wants a new git repository or GitHub repo created, cloned, or initialized, or an existing repo brought up to standard. Covers where repos live (c:/code), public vs private, protecting main (PRs, required checks, squash-only), repo security settings (secret scanning, Dependabot, auto-delete branches), the private-repo fallback when the plan has no branch protection, and baseline files (.gitignore with secret patterns, .gitattributes, .editorconfig, PR template, CI with gitleaks, dependabot.yml, LICENSE, README).
---

# New repository setup

Every repo follows the same standard so the `git-workflow` skill works everywhere: `main` changes only through squash-merged PRs that pass CI.

## 1. Location and visibility

- Repos live under **`c:/code/<repo-name>`**, never next to whatever folder is currently open.
- Ask **public or private** if the user hasn't said.
  - **Public:** everything in it is published forever — follow `public-repo-hygiene` from the first commit.
  - **Private:** fine for environment details, but still no secrets, and warn when adding infrastructure details (private repos get shared or made public later). On a free GitHub plan, private repos get **no server-side branch protection** (step 3b).

## 2. Create and clone

```powershell
Set-Location c:\code
gh repo create <repo-name> --public --add-readme --description "<description>" --clone   # or --private
Set-Location <repo-name>
```

Existing local folder instead: `git init -b main`, then (after a `-Scope History` hygiene scan if public) `gh repo create <repo-name> --source . --push`.

Get `<owner>` from `gh api user --jq .login`.

## 3. Repo settings

```bash
gh api -X PATCH repos/<owner>/<repo> -F delete_branch_on_merge=true \
  -F allow_squash_merge=true -F allow_merge_commit=false -F allow_rebase_merge=false \
  -f squash_merge_commit_title=PR_TITLE -f squash_merge_commit_message=PR_BODY
gh api -X PUT repos/<owner>/<repo>/vulnerability-alerts
gh api -X PUT repos/<owner>/<repo>/automated-security-fixes
# Public repos (paid plans for private): GitHub secret scanning with push protection
echo '{"security_and_analysis":{"secret_scanning":{"status":"enabled"},"secret_scanning_push_protection":{"status":"enabled"}}}' \
  | gh api -X PATCH repos/<owner>/<repo> --input -
```

### 3a. Protect main (public repos, or private on a paid plan)

Apply [assets/protect-main-ruleset.json](assets/protect-main-ruleset.json): PR required (0 approvals, so the user can merge their own), squash-only, no force-push, no deletion.

```bash
gh api -X POST repos/<owner>/<repo>/rulesets --input <path-to>/protect-main-ruleset.json
```

**After CI has run once**, add its job names as required checks. Edit the ruleset (`gh api repos/<owner>/<repo>/rulesets` for the id) and add this rule, with one entry per CI job (`integration_id` 15368 is GitHub Actions):

```json
{ "type": "required_status_checks", "parameters": { "strict_required_status_checks_policy": false,
  "required_status_checks": [ { "context": "<job name>", "integration_id": 15368 } ] } }
```

Then `gh api -X PUT repos/<owner>/<repo>/rulesets/<id> --input <file>` with the full ruleset.

### 3b. Private repo on a free plan

Rulesets fail with "Upgrade to GitHub Pro". Instead:

- Copy [assets/pre-push](assets/pre-push) to `hooks/pre-push` in the repo, commit it, and run `git config core.hooksPath hooks` in every clone (workstation-setup does this for the repos it manages). It refuses pushes to `main`.
- Note in the README that nothing on GitHub enforces PRs or checks for this repo.
- Tell the user, so they know merges there aren't gated.

## 4. Baseline files (on a branch, via PR)

Add these on a branch such as `chore/repo-setup` and open a PR (see `git-workflow`). Working copies are in the ai-skills repo root.

- **`.gitignore`**: the language's standard ignores, and **always** the secret patterns from `credentials-handling` (`config.local.json`, `*.local.json`, `.env`, `.env.*`, `!.env.example`, `*.pem`, `*.pfx`, `*.key`, `secrets/`).
- **`.gitattributes`**: `* text=auto eol=lf`, `*.ps1`/`*.bat`/`*.cmd` as `eol=crlf`, binaries marked `binary`.
- **`.editorconfig`**: UTF-8, final newline, trim trailing whitespace, 2-space default indent (4 where the language expects it).
- **`.github/pull_request_template.md`**: Summary / Why / Testing / Checklist (including "no secrets committed").
- **`.github/workflows/`**: the project's checks, plus a gitleaks secret-scan job. Start each workflow with `permissions: contents: read` and pin Actions to commit SHAs (see `supply-chain`).
- **`.gitleaks.toml`** (public repos): copy from the ai-skills root; it adds private-IP and MAC rules to gitleaks' defaults.
- **`.github/dependabot.yml`**: the `github-actions` ecosystem weekly, plus each package ecosystem the repo uses.
- **`LICENSE`** (public repos): ask the user. With no license file, others may read the code but have no right to reuse it; MIT is the common permissive choice.
- **`README.md`**: what it is and how to set it up, including "copy `config.example.json` to `config.local.json`" if the project has secrets.

## 5. Report back

Tell the user the repo URL, the local path, what protection is on (and what isn't, for free private repos), and that VS Code can open it with `code c:\code\<repo-name>` (you can't switch their window yourself).
