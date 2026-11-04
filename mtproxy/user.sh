#!/usr/bin/env bash
set -euo pipefail

cd -- "$(dirname -- "${BASH_SOURCE[0]}")"
umask 077

readonly CONFIG=config/config.toml
readonly SETTINGS=.env
readonly TLS_DOMAIN=github.com
readonly INTERNAL_PORT=443

usage() {
    printf 'Usage: bash user.sh <name> | bash user.sh --revoke <name>\n' >&2
    exit 1
}

read_settings() {
    local line key value
    local pattern='^(PUBLIC_HOST|PORT)=([A-Za-z0-9.-]+)$'
    local host= port= is_host_set=false is_port_set=false
    [[ -f $SETTINGS ]] || { printf 'Copy .env.example to %s and configure it.\n' "$SETTINGS" >&2; return 1; }
    while IFS= read -r line || [[ -n $line ]]; do
        if [[ $line =~ $pattern ]]; then
            key=${BASH_REMATCH[1]}
            value=${BASH_REMATCH[2]}
            if [[ $key == PUBLIC_HOST && $is_host_set == false ]]; then
                host=$value
                is_host_set=true
            elif [[ $key == PORT && $is_port_set == false ]]; then
                port=$value
                is_port_set=true
            else
                printf 'Duplicate %s in %s.\n' "$key" "$SETTINGS" >&2
                return 1
            fi
        elif [[ $line =~ ^(PUBLIC_HOST|PORT)[[:space:]]*= ]]; then
            printf 'Invalid setting in %s: %s\n' "$SETTINGS" "$line" >&2
            return 1
        fi
    done < "$SETTINGS"
    public_host=${PUBLIC_HOST-$host}
    public_port=${PORT-$port}
    if [[ -z $public_host || $public_host == 203.0.113.1 || ! $public_host =~ ^[A-Za-z0-9.-]+$ ]]; then
        printf 'Set the public VPS address in %s.\n' "$SETTINGS" >&2
        return 1
    fi
    if [[ ! $public_port =~ ^[1-9][0-9]{0,4}$ ]] || (( public_port > 65535 )); then
        printf 'Set PORT to a number from 1 to 65535 in %s.\n' "$SETTINGS" >&2
        return 1
    fi
}

initialize() {
    local uid gid
    uid=$(id -u)
    gid=$(id -g)
    if [[ $uid == 0 ]]; then
        uid=65532
        gid=65532
    fi
    mkdir -p config data
    if [[ ! -e $CONFIG ]]; then
        cat > "$CONFIG" <<EOF
[general]
use_middle_proxy = true

[general.modes]
classic = false
secure = false
tls = true

[general.links]
show = "*"

[server]
port = $INTERNAL_PORT

[server.api]
enabled = false

[censorship]
tls_domain = "$TLS_DOMAIN"
mask = true
mask_host = "$TLS_DOMAIN"
tls_emulation = true
tls_front_dir = "/data/tlsfront"

[access.users]
EOF
    fi
    if [[ $(id -u) == 0 ]]; then
        chown "$uid:$gid" config data "$CONFIG"
    fi
}

read_secret() {
    local name=$1 line section= pattern="^[[:space:]]*${name}[[:space:]]*=[[:space:]]*\"([0-9a-f]{32})\"[[:space:]]*$"
    local section_pattern='^\[([^]]+)\]$'
    while IFS= read -r line || [[ -n $line ]]; do
        if [[ $line =~ $section_pattern ]]; then
            section=${BASH_REMATCH[1]}
        elif [[ $section == access.users && $line =~ $pattern ]]; then
            printf '%s' "${BASH_REMATCH[1]}"
            return 0
        fi
    done < "$CONFIG"
    return 1
}

show_link() {
    local name=$1 host=$2 port=$3 secret=$4 domain_hex
    domain_hex=$(printf '%s' "$TLS_DOMAIN" | od -An -tx1 | tr -d ' \n')
    printf 'Link for %s:\ntg://proxy?server=%s&port=%s&secret=ee%s%s\n' "$name" "$host" "$port" "$secret" "$domain_hex"
    printf 'To revoke access: bash user.sh --revoke %s\n' "$name"
}

add_user() {
    local name=$1 host=$2 port=$3 secret
    if secret=$(read_secret "$name"); then
        printf 'User %s already exists.\n' "$name"
    else
        command -v openssl >/dev/null || { printf 'OpenSSL is required.\n' >&2; return 1; }
        secret=$(openssl rand -hex 16)
        printf '%s = "%s"\n' "$name" "$secret" >> "$CONFIG"
        printf 'Apply the configuration: docker compose up -d --force-recreate\n'
    fi
    show_link "$name" "$host" "$port" "$secret"
}

revoke_user() {
    local name=$1 temp
    if [[ ! -f $CONFIG ]] || ! read_secret "$name" >/dev/null; then
        printf 'User %s does not exist.\n' "$name" >&2
        return 1
    fi
    temp=$(mktemp config/.users.XXXXXXXX)
    if ! awk -v name="$name" '
        /^\[[^]]+\]$/ { section = $0 }
        section == "[access.users]" && $0 ~ "^[[:space:]]*" name "[[:space:]]*=" { next }
        { print }
    ' "$CONFIG" > "$temp"; then
        rm -f -- "$temp"
        return 1
    fi
    cat "$temp" > "$CONFIG"
    rm -f -- "$temp"
    printf 'Access revoked for %s.\n' "$name"
    printf 'Apply the configuration: docker compose up -d --force-recreate\n'
}

if [[ $# == 2 && $1 == --revoke ]]; then
    action=revoke
    name=$2
elif [[ $# == 1 ]]; then
    action=add
    name=$1
else
    usage
fi
[[ $name =~ ^[A-Za-z0-9_-]+$ && ${#name} -le 64 ]] || usage

if [[ $action == revoke ]]; then
    revoke_user "$name"
else
    read_settings
    initialize
    add_user "$name" "$public_host" "$public_port"
fi
