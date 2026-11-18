#!/usr/bin/env bash
set -euo pipefail

cd -- "$(dirname -- "${BASH_SOURCE[0]}")"

readonly COMPOSE_FILE=docker-compose.yml
readonly SERVICE=3x-ui
readonly USERNAME_BYTES=8
readonly PASSWORD_BYTES=24
readonly SUCCESS_MESSAGE='Username and password updated successfully'

reset_admin() {
    local username password output
    command -v openssl >/dev/null || { printf 'OpenSSL is required.\n' >&2; return 1; }
    command -v docker >/dev/null || { printf 'Docker with Compose is required.\n' >&2; return 1; }

    username=$(openssl rand -hex "$USERNAME_BYTES")
    password=$(openssl rand -base64 "$PASSWORD_BYTES")

    if ! output=$(docker compose -f "$COMPOSE_FILE" exec -T "$SERVICE" /app/x-ui setting \
        -username "$username" -password "$password" 2>&1); then
        printf 'Failed to reset admin credentials:\n%s\n' "$output" >&2
        return 1
    fi

    # The panel CLI can return zero even when updating credentials fails.
    if [[ $output != *"$SUCCESS_MESSAGE"* ]]; then
        printf 'Admin credential update was not confirmed:\n%s\n' "$output" >&2
        return 1
    fi

    printf 'Admin credentials updated. Save them in your password manager.\n'
    printf 'Username: %s\nPassword: %s\n' "$username" "$password"
}

reset_admin
