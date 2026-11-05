#!/usr/bin/env bash
set -euo pipefail

cd -- "$(dirname -- "${BASH_SOURCE[0]}")"
umask 077

readonly SETTINGS=.env
readonly UNPRIVILEGED_ID=65532

[[ -f $SETTINGS ]] || { printf 'Copy .env.example to %s and configure it.\n' "$SETTINGS" >&2; exit 1; }

if grep -q '^TELEMT_UID=' "$SETTINGS" || grep -q '^TELEMT_GID=' "$SETTINGS"; then
    if grep -q '^TELEMT_UID=' "$SETTINGS" && grep -q '^TELEMT_GID=' "$SETTINGS"; then
        printf 'TELEMT_UID and TELEMT_GID already exist in %s.\n' "$SETTINGS"
        exit 0
    fi
    printf 'Set both TELEMT_UID and TELEMT_GID in %s, or remove the existing one and rerun this script.\n' "$SETTINGS" >&2
    exit 1
fi

uid=$(id -u)
gid=$(id -g)
if [[ $uid == 0 ]]; then
    uid=$UNPRIVILEGED_ID
    gid=$UNPRIVILEGED_ID
fi

printf '\nTELEMT_UID=%s\nTELEMT_GID=%s\n' "$uid" "$gid" >> "$SETTINGS"
printf 'Added TELEMT_UID and TELEMT_GID to %s.\n' "$SETTINGS"
