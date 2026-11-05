# Telegram proxy

Telemt with Fake TLS and secure (`dd`) modes on the same port, using `github.com` as the Fake TLS masking domain. Requires Docker Compose, OpenSSL, a public VPS address, and an open TCP port (443 by default).

## Start

Copy `.env.example` to `.env` and set `PUBLIC_HOST` to the public IP or domain of the VPS. Set `PORT` to the external TCP port, which must be free and accessible from outside. Initialize the container IDs, then create the first user and save the link printed by the command:

```bash
cp .env.example .env
# Edit .env before continuing.
bash init-env.sh
bash user.sh alice
docker compose up -d
```

`init-env.sh` adds `TELEMT_UID` and `TELEMT_GID` to `.env` using the current user's UID and GID, or `65532` for both if run as root. Existing values are left unchanged. Run `init-env.sh` and `user.sh` as the same user.

`config.toml` contains the server settings and is mounted read-only. `user.sh` creates `config/users.toml` with the user secrets and the data directory; there is no need to run it again when restarting. Run Docker Compose from this directory as the same user. Shell environment variables take precedence over values in `.env`.

To change the port, update `PORT` in `.env`, open the new TCP port in the firewall, and run `docker compose up -d`. Run `bash user.sh <name>` to get each user's updated link. Existing links contain the old port and must be replaced.

## Upgrade an existing installation

Keep the existing `.env` with its IDs. If it lacks `PUBLIC_HOST` or `PORT`, add them from `.env.example` and set `PUBLIC_HOST` to the address previously used in the configuration.

The old `config/config.toml` contains both settings and user secrets. Before recreating the container:

1. Back up `config/config.toml` in a secure location.
2. Copy the entire `[access.users]` section, including the header and every user secret, into `config/users.toml`. Restrict the new file's permissions to its owner and keep it readable by `TELEMT_UID`.
3. Review the tracked `config.toml` and transfer any custom server settings from the old file. Keep `include = "users/users.toml"` and avoid adding secrets to it.
4. Run `docker compose up -d --force-recreate` and verify that existing users can connect.

The old `config/config.toml` is no longer used by the container. Preserve its backup until migration is verified.

## Add a user

```bash
bash user.sh bob
docker compose up -d --force-recreate
```

Send the appropriate generated link to the user. Both links use the same user secret and port; the secure link contains a `dd` secret for clients that do not support Fake TLS. Run `bash user.sh bob` again to display an existing user's links. To revoke access:

```bash
bash user.sh --revoke bob
docker compose up -d --force-recreate
```

Recreating the container temporarily interrupts connections. Revocation takes effect after the configuration is applied.

The files in `config/` contain secrets, and the links grant access to the proxy. Do not publish them. The `config/` and `data/` directories and the `.env` file are ignored by Git. To preserve access when migrating to a new server, back up `config/` and restore `.env`, updating the address, port, and user's UID and GID as needed.

Check the status and logs:

```bash
docker compose ps
docker compose logs --tail=100
```

The logs may also contain links and secrets. Proxy availability and masking depend on the client's network and should be tested from the user's device.
