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
if (( $# != 1 )); then
    printf 'Usage: sudo %s /var/backups/linux-admin/shared-TIMESTAMP.tar.gz\n' "$0" >&2
    exit 2
fi
archive="$1"
case "$archive" in
    "$BACKUP_DIR"/"${BACKUP_PREFIX}-"*.tar.gz) ;;
    *) printf 'Refusing archive outside the configured backup directory or with an unexpected name.\n' >&2; exit 1 ;;
esac
if [[ ! -f "$archive" ]]; then
    printf 'Backup archive not found: %s\n' "$archive" >&2
    exit 1
fi

install -d -o root -g root -m 0700 "$BACKUP_DIR" || exit 1
install -d "$SHARED_DIR" || exit 1

# Validate archive member paths before extraction. Backups should be created by this project.
listing="$(mktemp /var/tmp/linux-admin-archive-list.XXXXXX)" || exit 1
if ! tar -tzf "$archive" > "$listing"; then
    rm -f "$listing"
    printf 'Archive is unreadable or corrupt.\n' >&2
    exit 1
fi
while IFS= read -r member; do
    normalized="${member#./}"
    if [[ "$member" == /* || "/$normalized/" == *"/../"* ]]; then
        rm -f "$listing"
        printf 'Archive contains an unsafe path; refusing to restore.\n' >&2
        exit 1
    fi
done < "$listing"
rm -f "$listing"

# Preserve the current state before overwriting any files.
if ! "$PROJECT_ROOT/scripts/create-backup.sh" >/dev/null; then
    printf 'Could not create a pre-restore safety backup. Restore cancelled.\n' >&2
    exit 1
fi

staging_dir="$(mktemp -d /var/tmp/linux-admin-restore.XXXXXX)" || exit 1
cleanup() { rm -rf -- "$staging_dir"; }
trap cleanup EXIT
if ! tar --extract --gzip --file "$archive" --directory "$staging_dir" --same-owner --same-permissions; then
    printf 'Could not extract archive. Shared directory was not updated.\n' >&2
    exit 1
fi
if ! cp -a "$staging_dir/." "$SHARED_DIR/"; then
    printf 'Restore copy failed. Some files may already have been restored; inspect the directory.\n' >&2
    exit 1
fi
printf '%s [INFO] Restored %s into %s (merge mode)\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$archive" "$SHARED_DIR" >> "$BACKUP_DIR/backup.log"
printf 'Restore completed successfully.\n'
printf 'Files from the archive were restored/overwritten; unrelated current files were kept.\n'
