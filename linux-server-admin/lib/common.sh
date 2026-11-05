#!/usr/bin/env bash
# Shared functions used by the CLI and its modules.

LIB_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd -- "$LIB_DIR/.." && pwd)"
CONFIG_FILE="$PROJECT_ROOT/config/settings.conf"

if [[ ! -r "$CONFIG_FILE" ]]; then
    printf 'ERROR: Cannot read project configuration: %s\n' "$CONFIG_FILE" >&2
    return 1 2>/dev/null || exit 1
fi
# This is a project-owned configuration file, not arbitrary user input.
# shellcheck disable=SC1090
source "$CONFIG_FILE"

: "${SHARED_DIR:=/srv/linux-admin/shared}"
: "${SHARED_GROUP:=linuxshare}"
: "${BACKUP_DIR:=/var/backups/linux-admin}"
: "${BACKUP_PREFIX:=shared}"
: "${RETENTION_DAYS:=14}"
: "${BACKUP_SCHEDULE:=0 2 * * *}"
: "${CRON_FILE:=/etc/cron.d/linux-admin-backup}"
: "${CRON_INSTALL_DIR:=/usr/local/lib/linux-admin-pbl}"

LOG_DIR="$PROJECT_ROOT/logs"
APP_LOG="$LOG_DIR/admin.log"

# Fail early for unsafe or surprising configuration values.
if [[ "$SHARED_DIR" != /* || "$BACKUP_DIR" != /* || "$CRON_INSTALL_DIR" != /* || "$CRON_INSTALL_DIR" == "/" ]]; then
    printf 'ERROR: SHARED_DIR, BACKUP_DIR, and CRON_INSTALL_DIR must be valid absolute paths.\n' >&2
    return 1 2>/dev/null || exit 1
fi
case "$BACKUP_DIR/" in
    "$SHARED_DIR/"*)
        printf 'ERROR: BACKUP_DIR must not be inside SHARED_DIR.\n' >&2
        return 1 2>/dev/null || exit 1
        ;;
esac
if [[ ! "$SHARED_GROUP" =~ ^[a-z_][a-z0-9_-]*[$]?$ ]]; then
    printf 'ERROR: SHARED_GROUP in config/settings.conf is not a valid group name.\n' >&2
    return 1 2>/dev/null || exit 1
fi
if [[ ! "$RETENTION_DAYS" =~ ^[0-9]+$ ]]; then
    printf 'ERROR: RETENTION_DAYS must be a non-negative integer.\n' >&2
    return 1 2>/dev/null || exit 1
fi

print_header() {
    local title="$1"
    clear 2>/dev/null || true
    printf '\n============================================================\n'
    printf '  %s\n' "$title"
    printf '============================================================\n\n'
}

pause_screen() {
    printf '\n'
    read -r -p 'Press Enter to continue...' _ || true
}

confirm_action() {
    local prompt="$1" answer
    read -r -p "$prompt [y/N]: " answer || return 1
    [[ "$answer" == "y" || "$answer" == "Y" || "$answer" == "yes" || "$answer" == "YES" ]]
}

log_event() {
    local level="$1" message="$2"
    mkdir -p "$LOG_DIR" 2>/dev/null || true
    printf '%s [%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$level" "$message" >> "$APP_LOG" 2>/dev/null || true
}

is_valid_account_name() {
    [[ "$1" =~ ^[a-z_][a-z0-9_-]*[$]?$ ]]
}

user_exists() {
    getent passwd "$1" >/dev/null 2>&1
}

group_exists() {
    getent group "$1" >/dev/null 2>&1
}

require_sudo() {
    if ! command -v sudo >/dev/null 2>&1; then
        printf 'ERROR: sudo is not installed.\n' >&2
        return 1
    fi
    sudo -v
}

require_not_root() {
    if (( EUID == 0 )); then
        printf 'Please run this application as a normal user, not with sudo.\n'
        printf 'The individual administrative actions request sudo when needed.\n'
        return 1
    fi
}

show_result() {
    local status="$1" success_message="$2" failure_message="$3"
    if (( status == 0 )); then
        printf '\nSUCCESS: %s\n' "$success_message"
        log_event INFO "$success_message"
    else
        printf '\nERROR: %s\n' "$failure_message"
        log_event ERROR "$failure_message (exit status $status)"
    fi
}
