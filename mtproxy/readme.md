# Telegram proxy

Telemt with Fake TLS and `github.com` as the masking domain. Requires Docker Compose, OpenSSL, a public VPS address, and an open TCP port (443 by default).

## Start

Copy `.env.example` to `.env` and set `PUBLIC_HOST` to the public IP or domain of the VPS. Set `PORT` to the external TCP port, which must be free and accessible from outside. Then create the first user and save the link printed by the command:

```bash
cp .env.example .env
# Edit .env before continuing.
bash user.sh alice
docker compose up -d
```

The command creates the Telemt configuration and data directory; there is no need to run it again when restarting. The container runs with the UID and GID of the user who created the configuration, or `65532` for both if the command was run as root. Run Docker Compose from this directory as the same user.

The command adds these IDs to `.env` on first initialization. Shell environment variables take precedence over values in `.env`.

To change the port, update `PORT` in `.env`, open the new TCP port in the firewall, and run `docker compose up -d`. Run `bash user.sh <name>` to get each user's updated link. Existing links contain the old port and must be replaced.

If upgrading an existing installation, keep the existing `.env` with its IDs and add `PUBLIC_HOST` and `PORT` from `.env.example`, setting `PUBLIC_HOST` to the address previously used in `config.toml`.

## Add a user

```bash
bash user.sh bob
docker compose up -d --force-recreate
```

Send the generated link to the user. Run `bash user.sh bob` again to display an existing user's link. To revoke access:

```bash
bash user.sh --revoke bob
docker compose up -d --force-recreate
```

Recreating the container temporarily interrupts connections. Revocation takes effect after the configuration is applied.

The configuration in `config/` contains secrets, and the links grant access to the proxy. Do not publish them. The `config/` and `data/` directories and the `.env` file are ignored by Git. To preserve access when migrating to a new server, back up `config/` and restore `.env`, updating the address, port, and user's UID and GID as needed.

Check the status and logs:

```bash
docker compose ps
docker compose logs --tail=100
```

The logs may also contain links and secrets. Proxy availability and masking depend on the client's network and should be tested from the user's device.
