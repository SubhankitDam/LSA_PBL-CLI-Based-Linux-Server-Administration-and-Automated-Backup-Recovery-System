#!/usr/bin/env bash
set -uo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"
# shellcheck disable=SC1091
source "$PROJECT_ROOT/lib/common.sh" || exit 1

setup_shared_directory() {
    if ! group_exists "$SHARED_GROUP"; then
        printf 'The configured group "%s" does not exist.\n' "$SHARED_GROUP"
        if confirm_action "Create group $SHARED_GROUP now?"; then
            require_sudo || return
            sudo groupadd "$SHARED_GROUP" || { printf 'Could not create group.\n'; return; }
        else
            return
        fi
    fi
    require_sudo || return
    sudo install -d -o root -g "$SHARED_GROUP" -m 3770 "$SHARED_DIR"
    local status=$?
    if (( status == 0 )); then
        printf 'Shared directory is ready: %s\n' "$SHARED_DIR"
        printf 'Owner/group: root:%s | Mode: 3770\n' "$SHARED_GROUP"
        printf 'Add intended users to group "%s" using User & Group Management.\n' "$SHARED_GROUP"
        log_event INFO "Configured shared directory $SHARED_DIR with group $SHARED_GROUP"
    else
        printf 'Could not configure shared directory.\n'
        log_event ERROR "Failed to configure shared directory $SHARED_DIR"
    fi
}

show_shared_directory() {
    printf 'Configured shared directory: %s\n' "$SHARED_DIR"
    printf 'Configured sharing group:   %s\n\n' "$SHARED_GROUP"
    if [[ -d "$SHARED_DIR" ]]; then
        ls -ld "$SHARED_DIR"
        printf '\nDirectory contents:\n'
        ls -lah "$SHARED_DIR"
    else
        printf 'The shared directory has not been created yet.\n'
    fi
    printf '\nGroup details:\n'
    getent group "$SHARED_GROUP" || true
}

check_user_access() {
    local username
    read -r -p 'Username to test: ' username
    if ! is_valid_account_name "$username" || ! user_exists "$username"; then
        printf 'That is not a valid existing user.\n'; return
    fi
    if [[ ! -d "$SHARED_DIR" ]]; then
        printf 'Shared directory does not exist. Set it up first.\n'; return
    fi
    if sudo -u "$username" test -r "$SHARED_DIR" && sudo -u "$username" test -w "$SHARED_DIR" && sudo -u "$username" test -x "$SHARED_DIR"; then
        printf 'PASS: %s currently has read/write/traverse access to %s\n' "$username" "$SHARED_DIR"
    else
        printf 'FAIL: %s does not currently have full directory access.\n' "$username"
        printf 'Check group membership and ask the user to log out and back in.\n'
    fi
}

add_user_to_sharing_group() {
    local username status
    read -r -p 'Username to add to shared group: ' username
    if ! is_valid_account_name "$username" || ! user_exists "$username"; then
        printf 'That is not a valid existing user.\n'; return
    fi
    if ! group_exists "$SHARED_GROUP"; then
        printf 'Group %s does not exist. Set up the shared directory first.\n' "$SHARED_GROUP"; return
    fi
    require_sudo || return
    sudo usermod -aG "$SHARED_GROUP" "$username"
    status=$?
    show_result "$status" "Added $username to $SHARED_GROUP; a new login is required" "Could not add $username to $SHARED_GROUP"
}

setup_ssh_server() {
    if ! command -v sshd >/dev/null 2>&1 && [[ ! -x /usr/sbin/sshd ]]; then
        printf 'OpenSSH Server does not appear to be installed.\n'
        confirm_action 'Install openssh-server using APT?' || return
        require_sudo || return
        sudo apt-get install -y openssh-server || { printf 'Installation failed.\n'; return; }
    fi
    require_sudo || return
    sudo systemctl enable --now ssh
    local status=$?
    if (( status == 0 )); then
        printf 'SSH service is enabled and running. SFTP is provided by OpenSSH.\n'
        printf 'Server addresses: %s\n' "$(hostname -I 2>/dev/null || printf 'Run hostname -I to check')"
        printf 'From another machine, connect with: sftp USERNAME@SERVER_IP\n'
        log_event INFO 'Enabled OpenSSH service for SSH/SFTP access'
    else
        printf 'Could not enable/start the ssh service. Check: systemctl status ssh\n'
        log_event ERROR 'Could not enable/start OpenSSH service'
    fi
}

while true; do
    print_header 'FILE MANAGEMENT & SECURE SHARING'
    printf '  Shared path: %s\n' "$SHARED_DIR"
    printf '  Group:       %s\n\n' "$SHARED_GROUP"
    printf '  1. Create/configure shared directory\n'
    printf '  2. Add user to sharing group\n'
    printf '  3. Show directory permissions and contents\n'
    printf '  4. Test a user\x27s access\n'
    printf '  5. Enable/check SSH and SFTP service\n'
    printf '  0. Back to main menu\n\n'
    read -r -p 'Select an option: ' choice || exit 0
    case "$choice" in
        1) setup_shared_directory; pause_screen ;;
        2) add_user_to_sharing_group; pause_screen ;;
        3) show_shared_directory; pause_screen ;;
        4) check_user_access; pause_screen ;;
        5) setup_ssh_server; pause_screen ;;
        0) exit 0 ;;
        *) printf 'Invalid option.\n'; sleep 1 ;;
    esac
done
