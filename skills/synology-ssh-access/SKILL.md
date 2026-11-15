---
name: synology-ssh-access
description: Use when setting up or using SSH access to a Synology NAS (DSM 7) for an agent, script or service account — "create a service account", "SSH key for the NAS", "password not accepted", "permission denied (publickey)", "key login asks for a password", running read-only checks on the NAS, or deleting files over SSH. Covers the administrators-group requirement, user home and permission pitfalls, custom ports, restricting the key and sudo, Windows client quirks, and file-ownership limits of a service account.
---

# SSH access to a Synology NAS

## Rules

- **One account per agent or service** (e.g. `<purpose>_service_<host>`), never the user's own admin account: each can be audited and revoked on its own.
- **Key login only for the agent.** The account's password lives only in the user's password manager; the agent never sees it, so `sudo` stays out of reach.
- **Read-only by default** (see `homelab-changes`). Being in `administrators` is a DSM requirement, not permission to change things.
- Don't ask the user to paste passwords or private keys into chat, and don't read their `~/.ssh` folder unless they agree; run `ssh -G <alias>` to see the settings SSH applies instead.

## DSM facts that cause most failures

| Symptom | Cause | Fix |
|---|---|---|
| Correct password rejected | DSM only allows SSH for members of **administrators** | Add the account to administrators |
| `Connection refused` on 22 | SSH runs on a custom port | Ask for the port the user's own login uses; set `Port` in the SSH config |
| `Could not chdir to home directory` | User home service is off | Control Panel → User & Group → Advanced → Enable user home service |
| Key installed but still asks for password | Home folder too open (`drwxrwxrwx`) so sshd ignores the key | `chmod 755 ~`, `chmod 700 ~/.ssh`, `chmod 600 ~/.ssh/authorized_keys` |
| Alias "could not resolve hostname" | `~/.ssh/config` missing, saved with another name, or wrong encoding | Recreate with `Set-Content -Encoding ascii`; check with `ssh -G <alias>` |
| `rm: Permission denied` | Files owned by another user with `755`/`640` modes | The owner deletes them (File Station or their own SSH); don't escalate |

## Setup steps (Windows client)

1. DSM: create the account; add it to **administrators**; deny all applications (it only needs SSH); enable the user home service.
2. PC: `ssh-keygen -t ed25519 -f "$env:USERPROFILE\.ssh\<name>" -C "<account>@<workstation>"`. With a passphrase, enable the `ssh-agent` service (admin PowerShell) and `ssh-add` the key.
3. Install the key with restrictions, logging in with the password once:
   ```powershell
   $line = "no-port-forwarding,no-agent-forwarding,no-X11-forwarding $(Get-Content "$key.pub")"
   $line | ssh -p <port> <account>@<nas> "mkdir -p ~/.ssh && cat >> ~/.ssh/authorized_keys && chmod 700 ~/.ssh && chmod 600 ~/.ssh/authorized_keys && chmod 755 ~"
   ```
   If the password login itself is the problem, the user can install the key from their own admin login with `sudo` into `/var/services/homes/<account>/.ssh` and `chown` it.
4. Add a `Host` alias in `~/.ssh/config` with `HostName`, `Port`, `User`, `IdentityFile`, `IdentitiesOnly yes`.
5. Test: `ssh -o BatchMode=yes <alias> "id; df -h /volume1"` must succeed without a password prompt.
6. Optional root-only checks: a `/etc/sudoers.d/<account>` file allowing exact read-only commands with `NOPASSWD` (e.g. `du`, `btrfs subvolume list`, `docker system df`). Never allow plain `docker` (equivalent to root). DSM updates can reset this file.
7. Record the alias, account, port and access rules in the private environment skill, not in a public repo.

The key file name doesn't have to match the account name; mismatches between the two are a common source of confusion. Name them the same when possible.

## Running commands from Windows

- Use Windows OpenSSH (PowerShell) when the key is in the Windows `ssh-agent`; Git Bash's `ssh` doesn't use that agent.
- Pipe multi-line scripts as `($script -replace "`r","") | ssh <alias> 'bash -s'`. PowerShell here-strings have CRLF line endings, which break the last argument of each line on the NAS.
- Quote paths with apostrophes, brackets and spaces inside the remote script, not on the PowerShell command line.

## Useful read-only checks

- `df -h /volume1`; `ls /volume1` for shares; `du -sh /volume1/<share>/*` for sizes.
- Snapshots: `ls /var/packages` for the Snapshot Replication package and `#snapshot` folders; recycle bins: `du -sh /volume1/*/#recycle`.
- Container data under the compose data path; `/volume1/@docker` (images, layers) needs root.
