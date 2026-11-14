# Telegram proxy

`Telemt` provides Fake TLS and secure (`dd`) connections on the same TCP port. This setup uses `github.com` for TLS masking.

## Requirements

- A VPS with a public IPv4 address or domain.
- Docker with Docker Compose, Bash and OpenSSL installed.
- A free TCP port allowed by both the VPS firewall and the hosting provider's firewall. The default is `443`; use `8443` if `443` is already occupied.

## Prepare a fresh installation

Run from the repository's `mtproxy` directory on the VPS:

```bash
cd ~/deployments/mtproxy
bash setup.sh
```

Enter the public VPS address and external TCP port when prompted. The script:

1. Copies `.env.example` to `.env` and saves `PUBLIC_HOST` and `PORT`.
2. Calls `init-env.sh` to initialize `TELEMT_UID` and `TELEMT_GID`. When run as root, the container IDs are `65532:65532`; otherwise, they match the current user's IDs.
3. Creates `config/` and `data/`, then writes the required `[access.users]` header to `config/users.toml`, with no user entries.
4. Sets ownership and permissions for the container to read its config and write runtime data.

Setup is only for a fresh installation: it stops without changing files if `.env`, `config/` or `data/` already exists. It does not create users, start Docker, install dependencies or change firewalls. It can be invoked from another directory because it resolves its own location.

## Create the first user and start

Create a user separately, using the same account that ran setup:

```bash
bash user.sh alice
```

Save the printed Fake TLS and secure links. Open the chosen TCP port in your firewalls, then start the proxy:

```bash
docker compose up -d
docker compose ps
docker compose logs --tail=100 telemt
```

Open the Fake TLS link on the phone and enable the proxy in Telegram. The secure link is an alternative for clients without Fake TLS support.

## Files and secrets

| File | Purpose | Git |
| --- | --- | --- |
| `.env.example` | Template for the public address and external port | Tracked |
| `.env` | VPS address, external port and container IDs | Ignored |
| `config.toml` | Server settings; includes `users/users.toml` | Tracked |
| `config/users.toml` | User names and secrets | Ignored |
| `data/` | Runtime data and caches | Ignored |

Compose mounts `config.toml` at `/etc/telemt/config.toml` and `config/` at `/etc/telemt/users/`. The include therefore resolves to `/etc/telemt/users/users.toml` inside the container. The external `PORT` maps to container port `443`.

`user.sh` adds entries under the `[access.users]` header prepared by setup. Do not remove that header or put real secrets into `.env.example`. Proxy links contain secrets, and logs can contain those links.

## Add, display or revoke a user

After initial setup, use the same account to manage users:

```bash
bash user.sh bob
docker compose up -d --force-recreate
```

Running `bash user.sh bob` again prints the existing user's links. To revoke access:

```bash
bash user.sh --revoke bob
docker compose up -d --force-recreate
```

Recreating the container briefly interrupts connections.

## Change the public address or port

Edit `PUBLIC_HOST` or `PORT` in `.env`. Open the new TCP port if necessary, then apply the settings:

```bash
docker compose up -d --force-recreate
```

Generate updated links for every user with `bash user.sh <name>` and replace their old links. Shell variables override `.env` in Compose and `user.sh`; unset stale `PUBLIC_HOST`, `PORT`, `TELEMT_UID` or `TELEMT_GID` exports before using those commands.

## Troubleshooting

- `Config error: No such file or directory`: verify that `config.toml` and `config/users.toml` exist and that Compose mounts match the paths described above. Run setup before starting a fresh installation.
- `Unknown config key ignored ... key=<user name>`: the users file is missing `[access.users]`. Restore the header before user entries and recreate the container.
- `Permission denied` for caches or runtime files: check that `data/` and its contents are writable by `TELEMT_UID` and `TELEMT_GID` from `.env`.
- The container is `healthy`, but Telegram cannot connect: confirm the link uses the public VPS address and external `PORT`, confirm the user exists under `[access.users]`, and check firewall access from the client's network. Container health alone does not verify client authentication or external reachability.
