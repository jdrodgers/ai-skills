---
name: credentials-handling
description: Use whenever code needs a password, API key, token, connection string, client secret, certificate, or any other credential — writing new code that calls an authenticated service, adding config, reviewing code, or noticing a secret already in the source. Secrets never go in code or git; they live in a git-ignored local config file (or environment variables) read through one accessor, so a key vault can replace it later.
---

# Credentials handling

**Rule: no credential is ever written into source code, committed config, scripts, notebooks, tests, docs, commit messages, or logs.** This applies even to "temporary", "test", or "it's a private repo" secrets.

There is no key vault yet. Until there is, secrets live in a **local config file that git ignores**, with environment variables allowed to override it.

## What counts as a credential

Passwords, API keys, access/refresh tokens, PATs, OAuth client secrets, connection strings that contain a password, private keys and certificates (`.pem`, `.pfx`, `.key`), signing keys, webhook secrets, and session cookies. When unsure, treat it as a secret.

Not secrets (fine to commit): hostnames, ports, database names, usernames *without* passwords, feature flags, public client IDs.

## The pattern

Every project that needs secrets has these files:

| File | Committed? | Contents |
|---|---|---|
| `config.example.json` (or `.env.example`) | **Yes** | Every key the app needs, with placeholder values like `"<your-api-key>"`. Documents what to set. |
| `config.local.json` (or `.env`) | **Never** | The real values. Listed in `.gitignore`. |
| `.gitignore` | Yes | Contains the local file names *before* the local file is created. |

Lookup order at runtime: **environment variable → local config file → fail with a clear error.** Never fall back to a hard-coded default for a secret.

All secret reads go through **one function** (e.g. `get_secret("STRIPE_API_KEY")`). Nothing else in the codebase opens the config file or reads secret env vars directly. When a key vault arrives, only that function changes.

### Setup steps for a project

1. Add the ignore entries first, and confirm they work:
   ```
   # .gitignore
   config.local.json
   .env
   .env.*
   !.env.example
   *.pem
   *.pfx
   *.key
   secrets/
   ```
   Then check: `git check-ignore -v config.local.json` must print the matching rule.
2. Create `config.example.json` with placeholders and commit it.
3. Copy it to `config.local.json`, fill in real values locally. Do not `git add` it.
4. Add the single accessor (examples in [references/examples.md](references/examples.md)).
5. Document in the README: "Copy `config.example.json` to `config.local.json` and fill in values."

### Optional: keep secrets outside the repo entirely

For secrets shared across projects, or to remove any chance of committing them, put the file in the user profile instead of the repo:

- Windows: `%USERPROFILE%\.config\<app-name>\secrets.json`
- macOS/Linux: `~/.config/<app-name>/secrets.json`

The accessor checks the env var, then the repo-local file, then this path. On Windows, restrict it to the current user:
```powershell
icacls "$env:USERPROFILE\.config\<app-name>\secrets.json" /inheritance:r /grant:r "${env:USERNAME}:(R,W)"
```

## When writing or changing code

- Need a secret → add the key to `config.example.json` with a placeholder, read it through the accessor, tell the user which key to fill in locally. Do **not** ask the user to paste the real value into the chat or into code.
- Never print, log, or include secrets in exception messages. Log `"API key loaded from config.local.json"`, not the key. Mask if you must show it: first 4 chars + `…`.
- Tests use fake values or mocks, never real credentials. If an integration test needs a real one, it reads it through the accessor and is skipped when absent.
- CI/CD uses the platform's secret store (GitHub Actions `secrets.*`), exposed to the job as env vars — which the accessor already reads.
- Don't put secrets in command-line arguments (they show up in shell history and process lists). Use env vars or the config file.

## Before every commit

Check staged changes for secrets:
```bash
git diff --cached --name-only            # no config.local.json, .env, *.pem, *.pfx, *.key
git diff --cached | grep -inE "(password|secret|api[_-]?key|token|connectionstring|BEGIN .*PRIVATE KEY)"
```
Any hit gets a closer look before committing. Repos built from this skill set also run `gitleaks` in CI.

## If a secret has been committed

Deleting it in a new commit is **not enough** — it stays in git history, and on a public repo you should assume it has already been scraped.

1. **Rotate/revoke the credential first** at the provider. This is the step that actually fixes it.
2. Move the value into `config.local.json`, replace usages with the accessor, commit.
3. If it was never pushed: `git reset` / amend to drop it from local history.
4. If it was pushed: tell the user. Rewriting history (`git filter-repo`) needs a force-push and affects collaborators — only with explicit approval, and only after rotating.

## Reviewing code

Flag as a must-fix: string literals that look like keys/tokens/passwords, connection strings with `Password=`/`pwd=`, private key blocks, secrets in `appsettings.json`/`settings.py`/`config.js` that are committed, and secrets written to logs.
