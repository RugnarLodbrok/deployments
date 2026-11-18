#!/usr/bin/env bash
set -euo pipefail

cd -- "$(dirname -- "${BASH_SOURCE[0]}")"

readonly COMPOSE_FILE=docker-compose.yml
readonly SERVICE=3x-ui
readonly PATH_BYTES=16
readonly SUCCESS_MESSAGE='Base URI path set successfully'

reset_panel_path() {
    local path_token panel_path output
    command -v openssl >/dev/null || { printf 'OpenSSL is required.\n' >&2; return 1; }
    command -v docker >/dev/null || { printf 'Docker with Compose is required.\n' >&2; return 1; }

    path_token=$(openssl rand -hex "$PATH_BYTES")
    panel_path="/$path_token/"

    if ! output=$(docker compose -f "$COMPOSE_FILE" exec -T "$SERVICE" /app/x-ui setting \
        -webBasePath "$panel_path" 2>&1); then
        printf 'Failed to reset panel path:\n%s\n' "$output" >&2
        return 1
    fi

    # The panel CLI can return zero even when updating settings fails.
    if [[ $output != *"$SUCCESS_MESSAGE"* ]]; then
        printf 'Panel path update was not confirmed:\n%s\n' "$output" >&2
        return 1
    fi

    printf 'New panel path: %s\nAppend it to your panel origin (scheme, host and port).\n' "$panel_path"
    printf 'Restarting the container; Xray connections will be briefly interrupted.\n'
    if ! docker compose -f "$COMPOSE_FILE" restart "$SERVICE"; then
        printf 'The path was saved, but restart failed. Run: docker compose restart %s\n' "$SERVICE" >&2
        return 1
    fi
}

reset_panel_path
