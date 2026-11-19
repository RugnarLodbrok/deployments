# petushare

Static file sharing with `nginx` and Docker Compose. No database or build step.

## Start

On the VPS, from this directory:

```bash
cp .env.example .env
openssl rand -hex 32
```

Paste the generated value into `SHARE_KEY` in `.env`. Use only letters, digits,
underscores or hyphens for the key. Then start:

```bash
docker compose up -d
cp /path/to/archive.zip files/
```

Download: `http://YOUR_VPS_IP:8080/YOUR_SHARE_KEY/archive.zip`.
New files are available immediately; no restart is needed. Subdirectories work
too: `files/folder/archive.zip` becomes `/YOUR_SHARE_KEY/folder/archive.zip`.
Files must be readable by the container (`chmod a+r files/archive.zip` if needed).
Directories must allow traversal (`chmod a+rx files/folder` if needed).

Inbound TCP port `8080` must be allowed in the VPS firewall and hosting firewall.
To use another port, change `PORT` in `.env` and run `docker compose up -d`.

## Access

- The secret URL prefix comes from `SHARE_KEY` in `.env`. Requests without the
  correct prefix return `404`. Anyone with a file URL can download it.
- HTTP only: the key and files travel unencrypted.
- Access logging is disabled so request URLs are not written to the access log.
- Directory listings are disabled. Use hard-to-guess filenames for shared links.
- Files download as attachments. Hidden paths and symlinks are blocked.
- The container mounts `files/` read-only. Upload files using SSH/SCP or copy them
  on the VPS; there is no browser upload interface.
- Delete a file from `files/` to revoke its URL. Already downloaded copies remain.
- Shared files are excluded from Git.
- `.env` is excluded from Git. To revoke all links, change `SHARE_KEY` and run
  `docker compose up -d --force-recreate`.

## Stop

```bash
docker compose down
```

Files remain in `files/`.
