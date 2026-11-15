---
name: docker-practices
description: Use when writing or changing Dockerfiles, docker compose files, or container configuration, or when running containers. Covers pinned images, non-root users, secrets in env files rather than compose, limited ports and privileges, health checks, resource limits, volumes and backups, and validating changes before applying them.
---

# Docker practices

## Images

- Pin a specific version tag, never `:latest`. Use a digest (`image@sha256:...`) for anything you can't afford to have change underneath you.
- Prefer official or verified-publisher images, and small bases (`-slim`, `-alpine`, distroless) when they work.
- In Dockerfiles: multi-stage builds, `COPY` only what's needed (keep a `.dockerignore`), no secrets in build args or layers.

## Runtime security

- Run as a non-root user (`USER` in the Dockerfile, or `user:` in compose) when the image supports it.
- No `privileged: true`, no `network_mode: host`, and **never mount `/var/run/docker.sock`** unless it's essential and approved — socket access is root on the host.
- Drop what isn't needed: `cap_drop: [ALL]` then add back specific capabilities; `read_only: true` with `tmpfs` for scratch paths where possible; `security_opt: [no-new-privileges:true]`.
- Publish only the ports that must be reached, and bind to a specific interface (`127.0.0.1:8080:80`) when only local access is needed. Put a reverse proxy with TLS and auth in front of anything reachable from other machines.

## Secrets and config

- Secrets go in an `.env` file next to the compose file (git-ignored, with a committed `.env.example`) or in Docker secrets — never inline in `compose.yaml`. See `credentials-handling`.
- Keep compose files in git; keep their `.env` files out.
- Use placeholders for hostnames and addresses in anything public (see `public-repo-hygiene`).

## Reliability

- `healthcheck:` for every long-running service; `depends_on` with `condition: service_healthy` where order matters.
- `restart: unless-stopped` for services; set memory/CPU limits for anything that could run away.
- Log rotation: the `json-file` driver with `max-size` / `max-file`, or the host's default.

## Data

- Named volumes or explicit bind mounts for anything that must survive a container rebuild; know which paths hold state.
- Back up volume data and the compose + `.env` files. A container is disposable; its data isn't.

## Changing a running stack

Follow `homelab-changes` for live systems. For each stack:

```bash
docker compose config            # validate and see the resolved config
docker compose pull              # fetch pinned images
docker compose up -d             # apply
docker compose ps                # check state and health
docker compose logs --tail 50    # check for errors
```

Roll back by restoring the previous compose file / image tag and running `up -d` again. Keep the old tag written down before changing it.
