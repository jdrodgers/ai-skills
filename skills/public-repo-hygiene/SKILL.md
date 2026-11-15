---
name: public-repo-hygiene
description: Use before committing to, pushing to, or changing the visibility of any repo, and whenever writing docs, examples, configs, logs, screenshots, issues, PRs, or gists that will be public. Keeps infrastructure and personal details (IP addresses, hostnames, local domains, MAC addresses, Wi-Fi names, usernames in paths, emails, service/port maps, network layout, device models and versions) out of public repos — blocking for public repos, warning for private ones. Includes a scanner script.
---

# Public repo hygiene

**Rule: nothing that describes the user's real environment goes into a public repo** — not in files, commit messages, branch names, PR/issue text, screenshots, or logs. Treat everything pushed to a public repo as permanently published: forks, caches and scrapers keep it even after deletion.

For **private** repos the same details are allowed only when needed, and you **still warn** when adding them: private repos get forked, shared, made public, or leaked later.

## What counts

| Category | Examples of what to keep out | Use instead |
|---|---|---|
| Addresses | private IPv4 ranges (10.x, 172.16–31.x, 192.168.x, 100.64–127.x), link-local, IPv6 ULA (fd..), public home IP | `<host-ip>`, or documentation ranges `192.0.2.0/24`, `198.51.100.0/24`, `203.0.113.0/24`, `2001:db8::/32` |
| Names | hostnames, local domains (`.lan`, `.local`, `.internal`, `.home.arpa`), Wi-Fi SSIDs, device names | `<nas-host>`, `example.com`, `host.example` |
| Hardware | MAC addresses, serial numbers, exact model + firmware pairs | omit, or `<device-model>` |
| Layout | VLAN/subnet plans, firewall rules, port-forward lists, which service runs on which host, open ports | describe the pattern generically |
| Identity | Windows/Unix usernames in paths (`C:\Users\<name>`), personal emails, real names, phone numbers | `$env:USERPROFILE`, `~`, `<you>`, `you@example.com` |
| Configs and output | compose files, home-automation configs, DNS blocklists, router exports, logs, screenshots with real values | sanitized copies with placeholders |
| Secrets | always covered by the `credentials-handling` skill — never, in any repo | — |

Vendor-specific details about the user's own setup belong in the **private** skills repo (`ai-skills-private`), never in a public skill.

## Before committing or pushing

Run the scanner (it ships with this skill and is linked into `~/.claude/skills`):

```powershell
$scan = "$env:USERPROFILE\.claude\skills\public-repo-hygiene\scripts\Scan-RepoHygiene.ps1"
& $scan -Scope Staged      # before a commit: only what you're adding
& $scan                    # whole tree as it is now
& $scan -Scope History     # every commit -- required before making a repo public
```

- It checks GitHub for the repo's visibility. **Public, or unknown (no remote yet), blocks with exit 1. Private warns** (exit 0) unless `-Strict`.
- Matches are printed masked so the report can be shared with an agent safely. Open the file at the reported line to fix it.
- Your own hostnames, domains and other identifying words go in a **private terms file**, one per line (prefix `re:` for a regex): `%USERPROFILE%\.config\ai-skills\sensitive-terms.txt`. It lives outside every repo; workstation-setup creates it. **Agents must not read or print that file**; run the scanner instead.
- If a match is a deliberate, reviewed example (e.g. a documentation IP that happens to look private), add `hygiene: allow` to that line. Use sparingly.

CI in the user's public repos also runs gitleaks with a `.gitleaks.toml` that adds private-IP and MAC rules (copy it from the root of the ai-skills repo). CI can't see the private terms file, so the local scan still matters.

## When something is found

1. **Not committed yet:** replace it with a placeholder, re-stage, re-scan.
2. **Committed but not pushed:** fix it and amend or rewrite the local commits before pushing.
3. **Already pushed to a public repo:** tell the user right away. Assume it's been copied. Rewriting history needs a force-push and the user's explicit approval; for secrets, rotate first (see `credentials-handling`). For infrastructure details, consider whether anything should change (e.g. an exposed port or a revealing hostname).

## Making a repo public (or creating a public one)

1. `& $scan -Scope History -Strict` must come back clean.
2. Check issues, PRs, releases, wiki, and Actions logs for the same details.
3. Confirm with the user, then change visibility.

## Writing examples and docs

- Write examples with placeholders from the start; don't sanitize later.
- Don't describe the user's environment ("my NAS runs X on port Y"). Describe the technique.
- Don't paste real command output or logs. Trim and replace values.
- Screenshots: crop or blur addresses, names and device lists before adding them.
