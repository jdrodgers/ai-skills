---
name: git-workflow
description: Use when creating branches, committing, pushing, or opening pull requests in the user's repositories. main is protected and only changes through pull requests, so work always happens on a branch; covers branch naming, commit messages, pre-commit checks, and opening the PR with gh.
---

# Git workflow

`main` is protected on the user's repos: no direct pushes, no force-pushes, no deletion. Every change goes through a pull request.

## Branches

- Never commit on `main`. If you find yourself on it with changes, create a branch first: `git switch -c <branch>` (uncommitted changes carry over).
- Branch from an up-to-date main: `git fetch origin && git switch -c <branch> origin/main`.
- Names: `<type>/<short-kebab-description>`, e.g. `feature/initial-skills`, `fix/login-timeout`.
  Types: `feature`, `fix`, `chore`, `docs`, `refactor`, `test`.
- One branch per logical change. Don't mix an unrelated cleanup into a feature branch.

## Commits

- Commit only when the user asks (or the task clearly includes it).
- Stage specific paths, not `git add -A` blindly; review `git status` and `git diff --cached` first.
- Run the secret check from the `credentials-handling` skill before committing. Never commit `config.local.json`, `.env`, keys, or certificates.
- Message format:
  ```
  <type>: <imperative summary, ≤ 72 chars>

  <optional body: why the change was made, not a line-by-line of what>
  ```
  e.g. `feature: add credentials-handling skill`.
- Never use `--no-verify` or skip signing unless the user explicitly says to. If a hook fails, fix the cause.
- Prefer new commits over `--amend` once something has been pushed.

## Pushing and pull requests

```bash
git push -u origin <branch>
gh pr create --base main --title "<type>: <summary>" --body-file <file>
```

- The PR body follows `.github/pull_request_template.md` if the repo has one: what changed, why, how it was tested.
- Report the PR URL back to the user.
- Don't merge the PR unless asked. When asked, prefer `gh pr merge --squash --delete-branch` unless the repo uses another convention.
- After merge, clean up without checking out `main`:
  ```bash
  git fetch --prune origin
  git switch --detach origin/main
  git branch -d <branch>
  git push origin --delete <branch>   # if the merge didn't delete it
  ```
  Don't rely on `git switch main` — in `ai-skills`, `main` is checked out in a separate worktree (`c:\code\ai-skills-main`, which Claude Code loads skills from), and git refuses to check out a branch in two places. Starting every branch from `origin/main` works everywhere, worktree or not.

## Things not to do without explicit approval

- `git push --force` (use `--force-with-lease` if a force push on *your own* branch is truly needed)
- `git reset --hard`, `git clean -fd`, `git checkout -- <path>` on uncommitted work
- Rewriting history that has been pushed
- Changing branch protection / rulesets
