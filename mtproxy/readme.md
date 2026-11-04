# Telegram proxy

Telemt with Fake TLS and `github.com` as the masking domain. Requires Docker Compose, OpenSSL, a public VPS address, and an open TCP port 443.

## Start

Set the public IP or domain of the VPS in `config.toml`. Then create the first user and save the link printed by the command:

```bash
bash user.sh alice
docker compose up -d
```

The command creates the Telemt configuration and data directory; there is no need to run it again when restarting. The container runs with the UID and GID of the user who created the configuration, or `65532` for both if the command was run as root. Run Docker Compose from this directory as the same user.

The command also creates `.env` with these IDs. See `.env.example` for its format.

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

The configuration in `config/` contains secrets, and the links grant access to the proxy. Do not publish them. The `config/` and `data/` directories and the `.env` file are ignored by Git. To preserve access when migrating to a new server, back up `config/` and restore `.env` with the user's UID and GID on the new server.

Check the status and logs:

```bash
docker compose ps
docker compose logs --tail=100
```

The logs may also contain links and secrets. Proxy availability and masking depend on the client's network and should be tested from the user's device.
