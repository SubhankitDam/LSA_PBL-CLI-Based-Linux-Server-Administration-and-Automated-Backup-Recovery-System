#!/usr/bin/env bash
set -uo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"
# shellcheck disable=SC1091
source "$PROJECT_ROOT/lib/common.sh" || exit 1

list_backups() {
    printf 'Backup directory: %s\n\n' "$BACKUP_DIR"
    if ! sudo test -d "$BACKUP_DIR"; then
        printf 'No backup directory exists yet. Create the first backup.\n'; return
    fi
    sudo find "$BACKUP_DIR" -maxdepth 1 -type f -name "${BACKUP_PREFIX}-*.tar.gz" -printf '%TY-%Tm-%Td %TH:%TM  %s bytes  %f\n' | sort -r
}

create_backup() {
    require_sudo || return
    sudo "$PROJECT_ROOT/scripts/create-backup.sh"
}

restore_backup() {
    local -a archives=()
    local index=1 selected
    if ! sudo test -d "$BACKUP_DIR"; then
        printf 'No backup directory exists yet.\n'; return
    fi
    mapfile -t archives < <(sudo find "$BACKUP_DIR" -maxdepth 1 -type f -name "${BACKUP_PREFIX}-*.tar.gz" -printf '%f\n' | sort -r)
    if (( ${#archives[@]} == 0 )); then
        printf 'No backups were found.\n'; return
    fi
    printf 'Available backups:\n\n'
    for archive in "${archives[@]}"; do
        printf '  %2d. %s\n' "$index" "$archive"
        ((index+=1))
    done
    printf '\n'
    read -r -p 'Enter backup number (0 to cancel): ' selected
    [[ "$selected" == 0 ]] && return
    if [[ ! "$selected" =~ ^[0-9]+$ ]] || (( selected < 1 || selected > ${#archives[@]} )); then
        printf 'Invalid selection.\n'; return
    fi
    local chosen="${archives[$((selected-1))]}"
    printf '\nRestore uses a safe merge: files in the archive are restored/overwritten,\n'
    printf 'but files currently in the shared directory that are not in the archive are kept.\n'
    printf 'A safety backup of the current shared directory is created first.\n\n'
    confirm_action "Restore $chosen into $SHARED_DIR?" || { printf 'Cancelled.\n'; return; }
    require_sudo || return
    sudo "$PROJECT_ROOT/scripts/restore-backup.sh" "$BACKUP_DIR/$chosen"
}

show_backup_log() {
    if sudo test -f "$BACKUP_DIR/backup.log"; then
        sudo tail -n 25 "$BACKUP_DIR/backup.log"
    else
        printf 'No backup log exists yet.\n'
    fi
}

cron_status() {
    if sudo test -f "$CRON_FILE"; then
        printf 'Daily backup schedule is installed:\n\n'
        sudo cat "$CRON_FILE"
    else
        printf 'Daily backup schedule is not installed.\n'
    fi
}

install_schedule() {
    require_sudo || return
    sudo "$PROJECT_ROOT/scripts/install-cron.sh"
}

remove_schedule() {
    if ! confirm_action 'Remove the daily backup schedule?'; then printf 'Cancelled.\n'; return; fi
    require_sudo || return
    sudo "$PROJECT_ROOT/scripts/remove-cron.sh"
}

while true; do
    print_header 'BACKUP & RECOVERY'
    printf '  Shared directory: %s\n' "$SHARED_DIR"
    printf '  Backup directory: %s\n\n' "$BACKUP_DIR"
    printf '  1. Create backup now\n'
    printf '  2. List available backups\n'
    printf '  3. Restore a backup\n'
    printf '  4. Install daily automatic backup (cron)\n'
    printf '  5. Remove daily automatic backup\n'
    printf '  6. Show backup log\n'
    printf '  7. Show schedule status\n'
    printf '  0. Back to main menu\n\n'
    read -r -p 'Select an option: ' choice || exit 0
    case "$choice" in
        1) create_backup; pause_screen ;;
        2) list_backups; pause_screen ;;
        3) restore_backup; pause_screen ;;
        4) install_schedule; pause_screen ;;
        5) remove_schedule; pause_screen ;;
        6) show_backup_log; pause_screen ;;
        7) cron_status; pause_screen ;;
        0) exit 0 ;;
        *) printf 'Invalid option.\n'; sleep 1 ;;
    esac
done
