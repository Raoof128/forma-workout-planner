# Droplet and container hardening

[Back to security overview](README.md)

The Droplet was not accessed. This page records what the repository enforces
and the host checks an operator must run. Operational procedures are in
[infrastructure operations](../accounts-infrastructure.md).

## Enforced by the repository

| Control                | Where                                                                                                                               |
| ---------------------- | ----------------------------------------------------------------------------------------------------------------------------------- |
| Non-root API image     | `ops/Dockerfile` runs as UID 10001; CI asserts it                                                                                   |
| Digest-pinned images   | `node`, `postgres` and `cloudflared` are pinned by `sha256` in `ops/Dockerfile` and `ops/compose.yaml`; Dependabot proposes updates |
| No published ports     | `ops/compose.yaml` publishes nothing; the API is reachable only through `cloudflared`                                               |
| Database isolation     | `database` network is `internal: true`                                                                                              |
| Container restrictions | `read_only`, `cap_drop: [ALL]`, `no-new-privileges`, memory, CPU and PID limits, bounded logs                                       |
| Secrets as files       | Postgres administrator password and Tunnel token are Compose secrets                                                                |
| Password not on argv   | `ops/grant-runtime-access.sh` passes the migrator password through the environment, not the command line                            |

## Open items (owner)

| ID   | Item                                                                                                                                                       | Severity |
| ---- | ---------------------------------------------------------------------------------------------------------------------------------------------------------- | -------- |
| R-03 | `AUTH_SECRET`, `ORIGIN_SHARED_SECRET`, `DATABASE_URL` and the email token are environment variables, visible to `docker inspect`. Move to `_FILE` secrets. | Low      |
| R-04 | The API shares a plain bridge network with `cloudflared` and has unrestricted egress. Restrict egress to the email API (proxy or `DOCKER-USER` rules).     | Low      |
| R-15 | The `migrate` service lacks `read_only` and a tmpfs.                                                                                                       | Low      |
| R-16 | `.dockerignore` uses root-only `.env` patterns; use `**/.env*`.                                                                                            | Info     |

## Host checklist (BLOCKED until run on the Droplet)

- Supported Ubuntu LTS with unattended security updates; reboot policy defined.
- SSH: keys only, no root login, `AllowUsers` set; DigitalOcean cloud firewall
  allows SSH only from operator addresses and nothing else inbound.
- `ss -tlnp` shows no public listener; Docker publishes no ports.
- Docker socket not exposed to any container; operator account in the
  `docker` group only where intended.
- `/etc/forma` and secret files `0600` (Tunnel token readable by the container
  user; confirm without loosening permissions).
- Time sync (systemd-timesyncd or chrony) active; journald retention set.
- Disk alerts below 20 % free; PostgreSQL volume on its own volume if possible.
- `docker compose restart` and a host reboot recover the stack without data
  loss; workspace writes are transactional so committed revisions survive.
