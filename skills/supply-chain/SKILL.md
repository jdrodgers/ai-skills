---
name: supply-chain
description: Use when adding, updating, or installing dependencies, packages, tools, container images, GitHub Actions, VS Code extensions, MCP servers, or scripts from the internet. Covers choosing trustworthy sources, pinning versions (and Actions to commit SHAs), lock files, Dependabot, reviewing updates, and never piping downloads into a shell.
---

# Supply chain

Every dependency is code that runs with your access. Fewer, well-known, pinned dependencies are safer than many floating ones.

## Before adding something

- **Do you need it?** A few lines of your own code can beat a dependency.
- **Who publishes it?** Prefer official or widely used projects with recent releases and active maintainers. Check the exact name — typosquats copy popular names.
- **What does it pull in?** Look at its dependency count and any install scripts.
- For tools: install from the official source or a package manager (winget, the language's registry), not random download links.

## Pin versions

| Kind | Do |
|---|---|
| Language packages | Exact or locked versions, with the lock file committed (`package-lock.json`, `poetry.lock`, `uv.lock`, `packages.lock.json`) |
| Container images | A specific version tag, never `:latest`; a digest (`@sha256:...`) for anything important |
| GitHub Actions | A full commit SHA with the version as a comment: `uses: actions/checkout@<40-char-sha> # v4` |
| Scripts/tools from the web | A specific release, with its checksum verified when one is published |

Get an Action's SHA with: `gh api repos/<owner>/<action>/commits/<tag> --jq .sha`.

## Keep them updated, deliberately

- Every repo has `.github/dependabot.yml` (at least the `github-actions` ecosystem, plus each package ecosystem used), and Dependabot alerts and security updates turned on.
- Review update PRs before merging: read the changelog for majors, let CI run, and be suspicious of a new maintainer or a sudden new install script.
- Don't auto-merge dependency updates without CI.

## Never

- `curl ... | sh`, `iwr ... | iex`, or running a downloaded script before reading it.
- Installing from an unofficial mirror, fork, or a URL in an issue/comment.
- Disabling signature, checksum, or TLS verification to make an install work.
- Adding a dependency to fix a problem in an untrusted PR without reviewing what it does.

## GitHub Actions specifics

- Set `permissions:` at the top of each workflow (start with `contents: read`), and grant more per job only if needed.
- Don't use `pull_request_target` with a checkout of the PR's code.
- Third-party Actions get the same scrutiny as dependencies — prefer official ones (`actions/*`) or well-known publishers.
