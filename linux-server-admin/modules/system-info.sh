#!/usr/bin/env bash
set -uo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"
# shellcheck disable=SC1091
source "$PROJECT_ROOT/lib/common.sh" || exit 1

print_header 'SYSTEM INFORMATION'
printf 'Hostname:       %s\n' "$(hostname)"
printf 'Current user:   %s\n' "$(whoami)"
printf 'Date/time:      %s\n' "$(date)"
printf 'Uptime:         %s\n' "$(uptime -p 2>/dev/null || uptime)"
printf 'IP addresses:   %s\n\n' "$(hostname -I 2>/dev/null || printf 'Unavailable')"
printf '%s\n' 'Disk usage:'
df -h / "$SHARED_DIR" 2>/dev/null | awk '!seen[$0]++' || df -h /
printf '\n%s\n' 'Memory usage:'
free -h 2>/dev/null || printf 'free command is unavailable.\n'
printf '\n%s\n' 'SSH service:'
if command -v systemctl >/dev/null 2>&1; then
    systemctl is-active ssh 2>/dev/null || true
else
    printf 'systemctl is unavailable.\n'
fi
printf '\nApplication log: %s\n' "$APP_LOG"
pause_screen
