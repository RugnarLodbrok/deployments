#!/usr/bin/env bash
set -euo pipefail

# The install hook also runs during bootstrap, before `x-ui` becomes PID 1.
if [[ $(readlink /proc/1/exe) == /app/x-ui ]]; then
    kill -HUP 1
fi
