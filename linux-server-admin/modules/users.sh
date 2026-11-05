#!/usr/bin/env bash
set -uo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"
# shellcheck disable=SC1091
source "$PROJECT_ROOT/lib/common.sh" || exit 1

create_user() {
    local username status
    read -r -p 'New username (lowercase): ' username
    if ! is_valid_account_name "$username"; then
        printf 'Invalid username. Use lowercase letters, digits, _ or -; start with a letter or _.\n'
        return
    fi
    if user_exists "$username"; then
        printf 'User %s already exists.\n' "$username"
        return
    fi
    if ! require_sudo; then return; fi
    sudo useradd --create-home --shell /bin/bash "$username"
    status=$?
    if (( status != 0 )); then
        show_result "$status" '' "Could not create user $username"
        return
    fi
    printf 'User account created. Set its password now for interactive/SSH login.\n'
    sudo passwd "$username"
    status=$?
    if (( status == 0 )); then
        show_result 0 "Created user $username and set its password" ''
    else
        printf 'The account exists, but its password was not set. Run: sudo passwd %s\n' "$username"
        log_event WARN "User $username created but password setup failed"
    fi
}

create_group() {
    local group status
    read -r -p 'New group name (lowercase): ' group
    if ! is_valid_account_name "$group"; then
        printf 'Invalid group name. Use lowercase letters, digits, _ or -; start with a letter or _.\n'
        return
    fi
    if group_exists "$group"; then
        printf 'Group %s already exists.\n' "$group"
        return
    fi
    require_sudo || return
    sudo groupadd "$group"
    status=$?
    show_result "$status" "Created group $group" "Could not create group $group"
}

add_user_to_group() {
    local username group status
    read -r -p 'Username: ' username
    read -r -p 'Group: ' group
    if ! is_valid_account_name "$username" || ! is_valid_account_name "$group"; then
        printf 'Invalid username or group name.\n'
        return
    fi
    if ! user_exists "$username"; then printf 'User %s does not exist.\n' "$username"; return; fi
    if ! group_exists "$group"; then printf 'Group %s does not exist.\n' "$group"; return; fi
    require_sudo || return
    sudo usermod -aG "$group" "$username"
    status=$?
    show_result "$status" "Added $username to $group (new login required)" "Could not add $username to $group"
}

lock_user() {
    local username status
    read -r -p 'Username to lock: ' username
    if ! is_valid_account_name "$username" || ! user_exists "$username"; then
        printf 'That is not a valid existing user.\n'; return
    fi
    if [[ "$username" == root || "$username" == "${USER:-}" ]]; then
        printf 'Refusing to lock root or the account running this tool.\n'; return
    fi
    require_sudo || return
    sudo passwd -l "$username"
    status=$?
    show_result "$status" "Locked password for $username" "Could not lock $username"
}

unlock_user() {
    local username status
    read -r -p 'Username to unlock: ' username
    if ! is_valid_account_name "$username" || ! user_exists "$username"; then
        printf 'That is not a valid existing user.\n'; return
    fi
    require_sudo || return
    sudo passwd -u "$username"
    status=$?
    show_result "$status" "Unlocked password for $username" "Could not unlock $username"
}

delete_user() {
    local username status
    read -r -p 'Username to delete (home directory will be kept): ' username
    if ! is_valid_account_name "$username" || ! user_exists "$username"; then
        printf 'That is not a valid existing user.\n'; return
    fi
    if [[ "$username" == root || "$username" == "${USER:-}" ]]; then
        printf 'Refusing to delete root or the account running this tool.\n'; return
    fi
    printf 'This removes the account but deliberately keeps its home directory.\n'
    confirm_action "Delete account $username?" || { printf 'Cancelled.\n'; return; }
    require_sudo || return
    sudo userdel "$username"
    status=$?
    show_result "$status" "Deleted account $username (home directory kept)" "Could not delete account $username"
}

list_users() {
    printf 'Regular user accounts (UID 1000-59999):\n\n'
    getent passwd | awk -F: '$3 >= 1000 && $3 < 60000 {printf "  %-24s UID=%s\n", $1, $3}'
    printf '\nGroups configured on the system:\n\n'
    getent group | awk -F: '{printf "  %-24s GID=%s\n", $1, $3}' | head -n 40
    printf '\n(Showing at most 40 groups.)\n'
}

while true; do
    print_header 'USER & GROUP MANAGEMENT'
    printf '  1. Create user\n'
    printf '  2. Delete user (keeps home directory)\n'
    printf '  3. Create group\n'
    printf '  4. Add user to group\n'
    printf '  5. Lock user password\n'
    printf '  6. Unlock user password\n'
    printf '  7. List users and groups\n'
    printf '  0. Back to main menu\n\n'
    read -r -p 'Select an option: ' choice || exit 0
    case "$choice" in
        1) create_user; pause_screen ;;
        2) delete_user; pause_screen ;;
        3) create_group; pause_screen ;;
        4) add_user_to_group; pause_screen ;;
        5) lock_user; pause_screen ;;
        6) unlock_user; pause_screen ;;
        7) list_users; pause_screen ;;
        0) exit 0 ;;
        *) printf 'Invalid option.\n'; sleep 1 ;;
    esac
done
