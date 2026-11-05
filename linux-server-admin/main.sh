#!/usr/bin/env bash
set -uo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/lib/common.sh" || exit 1

if ! require_not_root; then
    exit 1
fi

if ! command -v sudo >/dev/null 2>&1; then
    printf 'This application requires sudo for administrative operations.\n' >&2
    exit 1
fi

while true; do
    print_header 'LINUX SERVER ADMINISTRATION TOOL'
    printf '  Project: CLI-Based Linux Server Administration\n'
    printf '           and Automated Backup & Recovery System\n\n'
    printf '  1. User & Group Management\n'
    printf '  2. File Management & Sharing\n'
    printf '  3. Backup & Recovery\n'
    printf '  4. System Information\n\n'
    printf '  0. Exit\n\n'
    read -r -p 'Select an option: ' choice || exit 0

    case "$choice" in
        1) bash "$PROJECT_ROOT/modules/users.sh" ;;
        2) bash "$PROJECT_ROOT/modules/files.sh" ;;
        3) bash "$PROJECT_ROOT/modules/backup.sh" ;;
        4) bash "$PROJECT_ROOT/modules/system-info.sh" ;;
        0)
            printf '\nGoodbye.\n'
            exit 0
            ;;
        *)
            printf '\nInvalid option. Please choose 0-4.\n'
            sleep 1
            ;;
    esac
done
