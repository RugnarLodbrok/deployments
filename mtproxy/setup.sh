#!/usr/bin/env bash
set -euo pipefail

cd -- "$(dirname -- "${BASH_SOURCE[0]}")"
umask 077

readonly SETTINGS=.env
readonly SETTINGS_EXAMPLE=.env.example
readonly USERS=config/users.toml
readonly PLACEHOLDER_HOST=203.0.113.1
readonly DEFAULT_PORT=443

require_fresh_setup() {
    local path
    for path in "$SETTINGS" config data; do
        if [[ -e $path || -L $path ]]; then
            printf '%s already exists. Setup is only for a fresh installation.\n' "$path" >&2
            return 1
        fi
    done
}

prompt_settings() {
    read -r -p 'Public VPS IPv4 address or domain: ' public_host
    if [[ -z $public_host || $public_host == "$PLACEHOLDER_HOST" || ! $public_host =~ ^[A-Za-z0-9.-]+$ ]]; then
        printf 'Enter a public IPv4 address or domain without a URL scheme or port.\n' >&2
        return 1
    fi
    read -r -p "External TCP port [$DEFAULT_PORT]: " public_port
    public_port=${public_port:-$DEFAULT_PORT}
    if [[ ! $public_port =~ ^[1-9][0-9]{0,4}$ ]] || (( public_port > 65535 )); then
        printf 'PORT must be a number from 1 to 65535.\n' >&2
        return 1
    fi
}

prepare_settings() {
    cp -- "$SETTINGS_EXAMPLE" "$SETTINGS"
    sed -i -e "s/^PUBLIC_HOST=.*/PUBLIC_HOST=$public_host/" \
        -e "s/^PORT=.*/PORT=$public_port/" "$SETTINGS"
    bash init-env.sh
}

prepare_directories() {
    local container_uid container_gid
    mkdir config data
    printf '[access.users]\n' > "$USERS"
    if [[ $(id -u) == 0 ]]; then
        container_uid=$(sed -n 's/^TELEMT_UID=//p' "$SETTINGS")
        container_gid=$(sed -n 's/^TELEMT_GID=//p' "$SETTINGS")
        chown "$container_uid:$container_gid" config "$USERS" data
    fi
    chmod 700 config data
    chmod 600 "$SETTINGS" "$USERS"
}

require_fresh_setup
prompt_settings
prepare_settings
prepare_directories

printf '\nConfiguration ready. Create the first user: bash user.sh <name>\n'
printf 'Allow inbound TCP %s in your VPS firewall, then run: docker compose up -d\n' "$public_port"
