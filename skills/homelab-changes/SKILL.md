---
name: homelab-changes
description: Use before planning or making any change to a live self-hosted system — container hosts and compose stacks, NAS, home automation, DNS or ad-blocking servers, routers, switches, access points, firewalls, VPNs, or anything else running at home. Read-only by default; changes need approval, a backup, a dry run, one change at a time, and a written rollback. Environment specifics live in the private homelab-environment skill.
---

# Changing live home systems

These systems run the house: a mistake can take down DNS for every device, lock the user out of the network, or lose data. Treat them like production.

## First: get the facts from the private skill

The details — which hosts exist, how they're reached, how each is backed up — are in the **private** `homelab-environment` skill (repo `ai-skills-private`). Read it before planning. If it isn't loaded or doesn't cover the system, ask the user instead of guessing hostnames, addresses, or paths.

Never copy those details into a public repo, issue, or outside service (see `public-repo-hygiene`).

## Default: read-only

Inspecting is fine: reading configs, logs, status, versions, container lists. Anything that changes state needs the user's approval for that specific change.

## Every change

1. **Plan.** Say what will change, why, on which system, and what could break (including "what else depends on this?", e.g. everything depends on DNS).
2. **Backup.** Take or confirm a backup/snapshot/export using the method in `homelab-environment`. No backup, no change.
3. **Dry run.** Validate first: config checks, `docker compose config`, a diff of the new vs old config, the tool's own "check configuration" command.
4. **Rollback.** Write down the exact steps to undo it before starting.
5. **Approval.** Show the plan, backup, and rollback; wait for a yes.
6. **One change at a time.** Apply it, then verify (service up, logs clean, dependent things still work) before the next one.
7. **Record it.** Note what changed and when, in the private repo if the user keeps a log there.

## Never, without explicit approval for that specific case

- Expose a service to the internet (port forwards, reverse-proxy routes, disabling a firewall rule, UPnP).
- Disable authentication, TLS, or a security feature "to test".
- Change the network you or the agent are connected through (management VLAN, firewall rules, Wi-Fi, DNS) — it can cut off access mid-change. Prefer a wired connection on an unaffected network.
- Update firmware or OS versions, or several devices at once.
- Mount the Docker socket into a container, or run containers privileged / with host networking.

## Secrets

Credentials for these systems follow `credentials-handling`: in `.env` files, the platform's secret store (e.g. a `secrets.yaml` referenced from config), or a password manager — never in compose files, committed configs, skills, or prompts.
