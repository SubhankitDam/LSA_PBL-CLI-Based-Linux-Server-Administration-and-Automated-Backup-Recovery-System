#!/usr/bin/env bash
set -uo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"
# shellcheck disable=SC1091
source "$PROJECT_ROOT/lib/common.sh" || exit 1
if (( EUID != 0 )); then
    printf 'Run this script through sudo.\n' >&2
    exit 1
fi
if [[ -f "$CRON_FILE" ]]; then
    rm -f -- "$CRON_FILE"
    printf 'Removed daily backup schedule: %s\n' "$CRON_FILE"
else
    printf 'No project cron schedule was installed.\n'
fi
