#!/usr/bin/env bash
set -euo pipefail

cd -- "$(dirname -- "${BASH_SOURCE[0]}")"
umask 077

readonly CONFIG=config/config.toml
readonly SETTINGS=config.toml
readonly TLS_DOMAIN=github.com
readonly PORT=443

usage() {
    printf 'Использование: bash user.sh <имя>\n' >&2
    exit 1
}

read_public_host() {
    local line host= pattern='^[[:space:]]*public_host[[:space:]]*=[[:space:]]*"([A-Za-z0-9.-]+)"[[:space:]]*$'
    local ignored='^[[:space:]]*(#.*)?$'
    while IFS= read -r line || [[ -n $line ]]; do
        if [[ $line =~ $pattern ]]; then
            if [[ -n $host ]]; then
                printf 'В %s указан более одного public_host.\n' "$SETTINGS" >&2
                return 1
            fi
            host=${BASH_REMATCH[1]}
        elif [[ ! $line =~ $ignored ]]; then
            printf 'Неверная строка в %s: %s\n' "$SETTINGS" "$line" >&2
            return 1
        fi
    done < "$SETTINGS"
    if [[ -z $host || $host == 203.0.113.1 ]]; then
        printf 'Укажите публичный адрес VPS в %s.\n' "$SETTINGS" >&2
        return 1
    fi
    printf '%s' "$host"
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
    if [[ ! -e .env ]]; then
        printf 'TELEMT_UID=%s\nTELEMT_GID=%s\n' "$uid" "$gid" > .env
    fi
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
port = $PORT

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

add_user() {
    local name=$1 secret
    if grep -qE "^${name}[[:space:]]*=" "$CONFIG"; then
        printf 'Пользователь %s уже существует.\n' "$name" >&2
        exit 1
    fi
    secret=$(openssl rand -hex 16)
    printf '%s = "%s"\n' "$name" "$secret" >> "$CONFIG"
    local domain_hex
    domain_hex=$(printf '%s' "$TLS_DOMAIN" | od -An -tx1 | tr -d ' \n')
    printf 'Ссылка для %s:\ntg://proxy?server=%s&port=%s&secret=ee%s%s\n' "$name" "$2" "$PORT" "$secret" "$domain_hex"
}

[[ $# == 1 ]] || usage
[[ $1 =~ ^[A-Za-z0-9_-]+$ && ${#1} -le 64 ]] || usage
command -v openssl >/dev/null || { printf 'Требуется openssl.\n' >&2; exit 1; }
public_host=$(read_public_host)
initialize
add_user "$1" "$public_host"
printf 'Примените настройки: docker compose up -d --force-recreate\n'
