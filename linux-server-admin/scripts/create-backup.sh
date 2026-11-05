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
if [[ ! -d "$SHARED_DIR" ]]; then
    printf 'Shared directory does not exist: %s\n' "$SHARED_DIR" >&2
    exit 1
fi
if ! command -v tar >/dev/null 2>&1; then
    printf 'tar is required but was not found.\n' >&2
    exit 1
fi

install -d -o root -g root -m 0700 "$BACKUP_DIR" || exit 1
umask 077
timestamp="$(date '+%Y%m%d-%H%M%S')"
archive="$BACKUP_DIR/${BACKUP_PREFIX}-${timestamp}.tar.gz"
# Avoid overwriting a backup if two runs happen within the same second.
if [[ -e "$archive" ]]; then
    archive="$BACKUP_DIR/${BACKUP_PREFIX}-${timestamp}-$$.tar.gz"
fi
temporary_archive="$(mktemp "$BACKUP_DIR/.${BACKUP_PREFIX}-backup.XXXXXX")" || exit 1

if tar -czpf "$temporary_archive" -C "$SHARED_DIR" .; then
    mv -- "$temporary_archive" "$archive" || { rm -f -- "$temporary_archive"; exit 1; }
    chmod 0600 "$archive"
    printf '%s [INFO] Backup created: %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$archive" >> "$BACKUP_DIR/backup.log"
    printf 'Backup created successfully:\n%s\n' "$archive"
    if [[ "$RETENTION_DAYS" =~ ^[0-9]+$ ]] && (( RETENTION_DAYS > 0 )); then
        find "$BACKUP_DIR" -maxdepth 1 -type f -name "${BACKUP_PREFIX}-*.tar.gz" -mtime "+$RETENTION_DAYS" -print -delete >> "$BACKUP_DIR/backup.log" 2>&1 || true
    fi
else
    status=$?
    rm -f -- "$temporary_archive"
    printf '%s [ERROR] Backup failed (exit %s)\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$status" >> "$BACKUP_DIR/backup.log"
    printf 'Backup failed. See %s/backup.log\n' "$BACKUP_DIR" >&2
    exit "$status"
fi
