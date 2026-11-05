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
if [[ "$PROJECT_ROOT" == *$'\n'* || "$PROJECT_ROOT" == *'"'* || "$CRON_INSTALL_DIR" == *$'\n'* || "$CRON_INSTALL_DIR" == *'"'* ]]; then
    printf 'Project or cron install path contains characters unsupported by this cron installer.\n' >&2
    exit 1
fi
# Basic check: cron schedule must contain exactly five whitespace-separated fields.
read -r -a schedule_fields <<< "$BACKUP_SCHEDULE"
if (( ${#schedule_fields[@]} != 5 )); then
    printf 'BACKUP_SCHEDULE must contain five cron fields (minute hour day month weekday).\n' >&2
    exit 1
fi
if [[ ! -x /usr/sbin/cron ]] && ! command -v cron >/dev/null 2>&1; then
    printf 'The cron service is not installed. Installing the cron package...\n'
    if ! command -v apt-get >/dev/null 2>&1 || ! apt-get install -y cron; then
        printf 'Could not install cron. Install it manually with: sudo apt-get install cron\n' >&2
        exit 1
    fi
fi
case "$CRON_INSTALL_DIR/" in
    "$PROJECT_ROOT/"*)
        printf 'CRON_INSTALL_DIR must be outside the project directory.\n' >&2
        exit 1
        ;;
esac
cron_parent="$(dirname -- "$CRON_INSTALL_DIR")"
if [[ ! -d "$cron_parent" || -L "$cron_parent" || -L "$CRON_INSTALL_DIR" ]]; then
    printf 'The cron install parent must exist and must not be a symlink.\n' >&2
    exit 1
fi
parent_owner="$(stat -c '%u' "$cron_parent")"
parent_mode="$(stat -c '%a' "$cron_parent")"
if [[ "$parent_owner" != 0 || ! "$parent_mode" =~ ^[0-7]{3,4}$ ]] || (( (8#$parent_mode & 0022) != 0 )); then
    printf 'The cron install parent must be root-owned and not writable by group/others.\n' >&2
    exit 1
fi
# Install a root-owned copy of the cron helper. The scheduled root job must
# never execute a script directly from the student's user-writable folder.
install -d -o root -g root -m 0755 \
    "$CRON_INSTALL_DIR/config" \
    "$CRON_INSTALL_DIR/lib" \
    "$CRON_INSTALL_DIR/scripts" || exit 1
install -o root -g root -m 0644 "$PROJECT_ROOT/config/settings.conf" "$CRON_INSTALL_DIR/config/settings.conf" || exit 1
install -o root -g root -m 0644 "$PROJECT_ROOT/lib/common.sh" "$CRON_INSTALL_DIR/lib/common.sh" || exit 1
install -o root -g root -m 0755 "$PROJECT_ROOT/scripts/create-backup.sh" "$CRON_INSTALL_DIR/scripts/create-backup.sh" || exit 1
install -d -o root -g root -m 0700 "$BACKUP_DIR" || exit 1
tmp_file="$(mktemp /tmp/linux-admin-cron.XXXXXX)" || exit 1
trap 'rm -f -- "$tmp_file"' EXIT
{
    printf 'SHELL=/bin/bash\n'
    printf 'PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin\n'
    printf '%s root /usr/bin/bash "%s/scripts/create-backup.sh"\n' "$BACKUP_SCHEDULE" "$CRON_INSTALL_DIR"
} > "$tmp_file"
install -o root -g root -m 0644 "$tmp_file" "$CRON_FILE" || exit 1
if command -v systemctl >/dev/null 2>&1; then
    if ! systemctl enable --now cron; then
        printf 'Cron schedule file was installed, but the cron service could not be started.\n' >&2
        exit 1
    fi
fi
printf 'Daily backup schedule installed in %s\n' "$CRON_FILE"
printf 'Schedule: %s (server local time)\n' "$BACKUP_SCHEDULE"
printf 'Root-owned helper copy: %s\n' "$CRON_INSTALL_DIR"
printf 'Reinstall the schedule after changing settings or backup scripts.\n' 
