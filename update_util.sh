#!/bin/sh
# System Update Utility - Ubuntu/Debian
# Safe system updates, package repair, cleanup, reporting, and optional notifications.

SCRIPT_VERSION="3.0.0"
AUTO_YES=false
DRY_RUN=false
NOTIFY=false
CLEAR_CACHE=false
CLEAR_HISTORY=false
FULL_UPGRADE=false
DOCKER_CLEANUP=false
COLOR_ENABLED=true
LOCK_DIR="/run/lock/system-update-utility.lock"
LOG_FILE="/var/log/sysupdate.log"
WARNINGS=0

show_help() {
    cat <<USAGE
Usage: sudo ./update_util_updated.sh [OPTIONS]

Options:
  -h, --help             Show this help message and exit
  -v, --version          Show version information
  -y, --yes              Automatically confirm APT package operations
  -d, --dry-run          Show planned actions without changing the system
      --notify           Send a desktop notification when finished
      --clear-cache      Clear selected safe user caches
      --clear-history    Clear Bash and Zsh history files
      --full-upgrade     Use apt-get full-upgrade instead of upgrade
      --docker-cleanup   Run 'docker system prune --volumes' if Docker is installed
      --no-color         Disable coloured terminal output

Examples:
  sudo ./update_util_updated.sh
  sudo ./update_util_updated.sh --yes --full-upgrade
  sudo ./update_util_updated.sh --dry-run --clear-cache
  sudo ./update_util_updated.sh --yes --docker-cleanup

Safety notes:
  --yes only affects APT confirmations. It does not automatically enable
  cache deletion, terminal-history deletion, or Docker cleanup.
USAGE
}

while [ "$#" -gt 0 ]; do
    case "$1" in
        -h|--help)
            show_help
            exit 0
            ;;
        -v|--version)
            printf 'System Update Utility v%s\n' "$SCRIPT_VERSION"
            exit 0
            ;;
        -y|--yes)
            AUTO_YES=true
            ;;
        -d|--dry-run)
            DRY_RUN=true
            ;;
        --notify)
            NOTIFY=true
            ;;
        --clear-cache)
            CLEAR_CACHE=true
            ;;
        --clear-history)
            CLEAR_HISTORY=true
            ;;
        --full-upgrade)
            FULL_UPGRADE=true
            ;;
        --docker-cleanup)
            DOCKER_CLEANUP=true
            ;;
        --no-color)
            COLOR_ENABLED=false
            ;;
        --)
            shift
            break
            ;;
        *)
            printf 'Unknown option: %s\n\n' "$1" >&2
            show_help >&2
            exit 1
            ;;
    esac
    shift
done

set -eu
LC_ALL=C
export LC_ALL

if [ "$COLOR_ENABLED" = true ] && [ -t 1 ]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    BLUE='\033[0;34m'
    CYAN='\033[0;36m'
    YELLOW='\033[1;33m'
    BOLD='\033[1m'
    NC='\033[0m'
else
    RED=''
    GREEN=''
    BLUE=''
    CYAN=''
    YELLOW=''
    BOLD=''
    NC=''
fi

info() {
    printf '%b==>%b %b%s%b\n' "$BLUE" "$NC" "$BOLD" "$1" "$NC"
}

warn() {
    WARNINGS=$((WARNINGS + 1))
    printf '%bWARNING:%b %s\n' "$YELLOW" "$NC" "$1" >&2
}

fatal() {
    printf '%bERROR:%b %s\n' "$RED" "$NC" "$1" >&2
    exit 1
}

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

human_bytes() {
    value=${1:-0}
    if command_exists numfmt; then
        numfmt --to=iec "$value" 2>/dev/null || printf '%s bytes\n' "$value"
    else
        printf '%s bytes\n' "$value"
    fi
}

get_directory_bytes() {
    target=$1
    if [ -e "$target" ]; then
        du -sb "$target" 2>/dev/null | awk 'NR == 1 {print $1}'
    else
        printf '0\n'
    fi
}

get_available_bytes() {
    target=$1
    df -P -B1 "$target" 2>/dev/null | awk 'NR == 2 {print $4}'
}

get_journal_bytes() {
    if ! command_exists journalctl; then
        printf '0\n'
        return
    fi

    journal_size=$(journalctl --disk-usage --no-pager 2>/dev/null \
        | sed -n 's/.*take up \([^ ]*\).*/\1/p' \
        | head -n 1)

    if [ -n "$journal_size" ] && command_exists numfmt; then
        numfmt --from=iec "$journal_size" 2>/dev/null || printf '0\n'
    else
        printf '0\n'
    fi
}

run_command() {
    if [ "$DRY_RUN" = true ]; then
        printf '%b[DRY RUN]%b' "$CYAN" "$NC"
        for arg in "$@"; do
            printf ' %s' "$arg"
        done
        printf '\n'
        return 0
    fi

    "$@"
}

run_apt() {
    if [ "$DRY_RUN" = true ]; then
        printf '%b[DRY RUN]%b apt-get' "$CYAN" "$NC"
        for arg in "$@"; do
            printf ' %s' "$arg"
        done
        if [ "$AUTO_YES" = true ]; then
            printf ' -y'
        fi
        printf '\n'
        return 0
    fi

    if [ "$AUTO_YES" = true ]; then
        DEBIAN_FRONTEND=noninteractive apt-get "$@" -y
    else
        apt-get "$@"
    fi
}

send_notification() {
    message=$1

    [ "$NOTIFY" = true ] || return 0
    [ "$DRY_RUN" = false ] || return 0
    command_exists notify-send || return 0

    if [ "$REAL_USER" = "root" ]; then
        notify-send "System Update Utility" "$message" >/dev/null 2>&1 || true
        return 0
    fi

    user_id=$(id -u "$REAL_USER" 2>/dev/null || printf '')
    [ -n "$user_id" ] || return 0

    display_value=${DISPLAY:-:0}
    runtime_dir="/run/user/$user_id"
    dbus_address="unix:path=$runtime_dir/bus"

    if command_exists runuser; then
        runuser -u "$REAL_USER" -- env \
            DISPLAY="$display_value" \
            XDG_RUNTIME_DIR="$runtime_dir" \
            DBUS_SESSION_BUS_ADDRESS="$dbus_address" \
            notify-send "System Update Utility" "$message" >/dev/null 2>&1 || true
    fi
}

cleanup_lock() {
    if [ "${LOCK_ACQUIRED:-false}" = true ]; then
        rmdir "$LOCK_DIR" 2>/dev/null || true
    fi
}

trap cleanup_lock EXIT HUP INT TERM

# Root privileges are required only for real maintenance operations.
# Dry-run mode performs no system modifications and is safe for CI/non-root use.
if [ "$DRY_RUN" = false ] && [ "$(id -u)" -ne 0 ]; then
    fatal "Run this script as root, for example: sudo ./update_util_updated.sh"
fi

if [ ! -r /etc/os-release ]; then
    fatal "Cannot detect the operating system because /etc/os-release is missing."
fi

# shellcheck disable=SC1091
. /etc/os-release
case "${ID:-}" in
    ubuntu|debian|linuxmint|pop)
        ;;
    *)
        case " ${ID_LIKE:-} " in
            *" debian "*) ;;
            *) fatal "This script supports Debian-based systems only. Detected: ${PRETTY_NAME:-unknown}." ;;
        esac
        ;;
esac

command_exists apt-get || fatal "apt-get is not installed."
command_exists dpkg || fatal "dpkg is not installed."

if [ "$DRY_RUN" = false ]; then
    if mkdir "$LOCK_DIR" 2>/dev/null; then
        LOCK_ACQUIRED=true
    else
        fatal "Another instance appears to be running. Remove $LOCK_DIR only if no update process is active."
    fi
fi

if [ -n "${SUDO_USER:-}" ] && [ "$SUDO_USER" != "root" ]; then
    REAL_USER=$SUDO_USER
else
    REAL_USER=${LOGNAME:-root}
    [ -n "$REAL_USER" ] || REAL_USER=root
fi

REAL_HOME=$(getent passwd "$REAL_USER" 2>/dev/null | cut -d: -f6)
if [ -z "$REAL_HOME" ] || [ ! -d "$REAL_HOME" ]; then
    REAL_USER=root
    REAL_HOME=/root
    warn "Could not determine the invoking user's home directory; using /root."
fi

printf '%b**************************************************%b\n' "$CYAN$BOLD" "$NC"
printf '%b*        Linux System Update Utility             *%b\n' "$CYAN$BOLD" "$NC"
printf '%b*                    v%-26s*%b\n' "$CYAN$BOLD" "$SCRIPT_VERSION" "$NC"
printf '%b**************************************************%b\n' "$CYAN$BOLD" "$NC"
printf 'Operating system : %s\n' "${PRETTY_NAME:-unknown}"
printf 'Target user      : %s\n' "$REAL_USER"
printf 'Dry-run mode     : %s\n' "$DRY_RUN"
printf 'APT auto-confirm : %s\n\n' "$AUTO_YES"

info "Collecting disk usage before maintenance..."
APT_CACHE_BEFORE=$(get_directory_bytes /var/cache/apt/archives)
APP_CACHE_BEFORE=$(get_directory_bytes "$REAL_HOME/.cache")
JOURNAL_BEFORE=$(get_journal_bytes)
DISK_BEFORE=$(get_available_bytes /)

APT_CACHE_BEFORE=${APT_CACHE_BEFORE:-0}
APP_CACHE_BEFORE=${APP_CACHE_BEFORE:-0}
JOURNAL_BEFORE=${JOURNAL_BEFORE:-0}
DISK_BEFORE=${DISK_BEFORE:-0}

LOW_SPACE_THRESHOLD=10737418240
if [ "$DISK_BEFORE" -gt 0 ] && [ "$DISK_BEFORE" -lt "$LOW_SPACE_THRESHOLD" ]; then
    disk_human=$(human_bytes "$DISK_BEFORE")
    warn "Low disk space: only $disk_human is available on the root filesystem."
    send_notification "Low disk space: only $disk_human remains."
fi

info "Finishing interrupted package configuration..."
run_command dpkg --configure -a

info "Repairing broken package dependencies..."
run_apt install -f

info "Updating package lists..."
if [ "$DRY_RUN" = true ]; then
    printf '%b[DRY RUN]%b apt-get update\n' "$CYAN" "$NC"
else
    apt-get update
fi

if [ "$FULL_UPGRADE" = true ]; then
    info "Performing a full package upgrade..."
    run_apt full-upgrade
else
    info "Upgrading installed packages..."
    run_apt upgrade
fi

info "Removing unnecessary packages..."
run_apt autoremove --purge

info "Cleaning downloaded package files..."
if [ "$DRY_RUN" = true ]; then
    printf '%b[DRY RUN]%b apt-get autoclean\n' "$CYAN" "$NC"
    printf '%b[DRY RUN]%b apt-get clean\n' "$CYAN" "$NC"
else
    apt-get autoclean
    apt-get clean
fi

if [ "$CLEAR_CACHE" = true ]; then
    info "Clearing selected user caches..."

    if [ "$DRY_RUN" = true ]; then
        printf '%b[DRY RUN]%b Remove thumbnail cache under %s\n' "$CYAN" "$NC" "$REAL_HOME/.cache/thumbnails"
        printf '%b[DRY RUN]%b Remove fontconfig cache under %s\n' "$CYAN" "$NC" "$REAL_HOME/.cache/fontconfig"
        printf '%b[DRY RUN]%b Remove legacy thumbnails under %s\n' "$CYAN" "$NC" "$REAL_HOME/.thumbnails"
    else
        rm -rf "$REAL_HOME/.cache/thumbnails" 2>/dev/null || true
        rm -rf "$REAL_HOME/.cache/fontconfig" 2>/dev/null || true
        rm -rf "$REAL_HOME/.thumbnails" 2>/dev/null || true

        mkdir -p "$REAL_HOME/.cache"
        if [ "$REAL_USER" != "root" ]; then
            chown "$REAL_USER:" "$REAL_HOME/.cache" 2>/dev/null || true
        fi
    fi
else
    printf 'Skipping user-cache cleanup. Use --clear-cache to enable it.\n'
fi

if command_exists journalctl; then
    info "Cleaning systemd journal logs while keeping the last 7 days..."
    run_command journalctl --vacuum-time=7d
else
    warn "journalctl is unavailable; journal cleanup was skipped."
fi

info "Listing held packages..."
if [ "$DRY_RUN" = true ]; then
    printf '%b[DRY RUN]%b apt-mark showhold\n' "$CYAN" "$NC"
else
    apt-mark showhold || warn "Unable to list held packages."
fi

info "Checking package database consistency..."
if [ "$DRY_RUN" = true ]; then
    printf '%b[DRY RUN]%b apt-get check\n' "$CYAN" "$NC"
else
    apt-get check || warn "Package inconsistencies were detected."
fi

info "Checking package-file integrity..."
if command_exists debsums; then
    if [ "$DRY_RUN" = true ]; then
        printf '%b[DRY RUN]%b debsums -s\n' "$CYAN" "$NC"
    else
        debsums -s || warn "The debsums integrity check reported changed or missing files."
    fi
else
    printf 'debsums is not installed; package-file integrity checking was skipped.\n'
fi

if command_exists snap; then
    info "Refreshing Snap packages..."
    run_command snap refresh

    info "Removing disabled Snap revisions..."
    if [ "$DRY_RUN" = true ]; then
        snap list --all 2>/dev/null | awk '/disabled/{print $1, $3}' | while read -r snap_name revision; do
            [ -n "$snap_name" ] || continue
            printf '%b[DRY RUN]%b snap remove %s --revision=%s\n' "$CYAN" "$NC" "$snap_name" "$revision"
        done
    else
        snap list --all 2>/dev/null | awk '/disabled/{print $1, $3}' | while read -r snap_name revision; do
            [ -n "$snap_name" ] || continue
            printf 'Removing old Snap revision: %s (%s)\n' "$snap_name" "$revision"
            snap remove "$snap_name" --revision="$revision" || true
        done
    fi
else
    printf 'Snap is not installed; Snap maintenance was skipped.\n'
fi

if command_exists docker; then
    if [ "$DOCKER_CLEANUP" = true ]; then
        info "Cleaning up unused Docker resources..."
        run_command docker system prune --volumes -f
    else
        printf 'Skipping Docker cleanup. Use --docker-cleanup to enable it.\n'
    fi
else
    printf 'Docker is not installed; Docker cleanup was skipped.\n'
fi

if [ "$CLEAR_HISTORY" = true ]; then
    info "Clearing shell history files..."

    for history_file in "$REAL_HOME/.bash_history" "$REAL_HOME/.zsh_history"; do
        if [ -f "$history_file" ]; then
            if [ "$DRY_RUN" = true ]; then
                printf '%b[DRY RUN]%b Clear %s\n' "$CYAN" "$NC" "$history_file"
            else
                : >"$history_file"
                if [ "$REAL_USER" != "root" ]; then
                    chown "$REAL_USER:" "$history_file" 2>/dev/null || true
                fi
                printf 'Cleared %s\n' "$history_file"
            fi
        fi
    done
else
    printf 'Skipping terminal-history cleanup. Use --clear-history to enable it.\n'
fi

info "Collecting disk usage after maintenance..."
APT_CACHE_AFTER=$(get_directory_bytes /var/cache/apt/archives)
APP_CACHE_AFTER=$(get_directory_bytes "$REAL_HOME/.cache")
JOURNAL_AFTER=$(get_journal_bytes)
DISK_AFTER=$(get_available_bytes /)

APT_CACHE_AFTER=${APT_CACHE_AFTER:-0}
APP_CACHE_AFTER=${APP_CACHE_AFTER:-0}
JOURNAL_AFTER=${JOURNAL_AFTER:-0}
DISK_AFTER=${DISK_AFTER:-0}

APT_DIFF=$((APT_CACHE_BEFORE - APT_CACHE_AFTER))
APP_DIFF=$((APP_CACHE_BEFORE - APP_CACHE_AFTER))
JOURNAL_DIFF=$((JOURNAL_BEFORE - JOURNAL_AFTER))
PART_CLEARED=$((DISK_AFTER - DISK_BEFORE))

[ "$APT_DIFF" -ge 0 ] || APT_DIFF=0
[ "$APP_DIFF" -ge 0 ] || APP_DIFF=0
[ "$JOURNAL_DIFF" -ge 0 ] || JOURNAL_DIFF=0
[ "$PART_CLEARED" -ge 0 ] || PART_CLEARED=0

TOTAL_SAVED=$((APT_DIFF + APP_DIFF + JOURNAL_DIFF))
HUMAN_TOTAL=$(human_bytes "$TOTAL_SAVED")
HUMAN_PART_SAVED=$(human_bytes "$PART_CLEARED")

printf '\n%b========== MAINTENANCE SUMMARY ==========%b\n' "$BOLD$CYAN" "$NC"
printf 'APT cache cleared      : %b%s%b\n' "$BOLD" "$(human_bytes "$APT_DIFF")" "$NC"
printf 'Selected app caches    : %b%s%b\n' "$BOLD" "$(human_bytes "$APP_DIFF")" "$NC"
printf 'Journal logs cleared   : %b%s%b\n' "$BOLD" "$(human_bytes "$JOURNAL_DIFF")" "$NC"
printf '%s\n' '-----------------------------------------'
printf 'Measured cache savings : %b%s%b\n' "$GREEN$BOLD" "$HUMAN_TOTAL" "$NC"
printf 'Root filesystem gain   : %b%s%b\n' "$GREEN$BOLD" "$HUMAN_PART_SAVED" "$NC"
printf 'Warnings               : %b%s%b\n' "$YELLOW$BOLD" "$WARNINGS" "$NC"

if [ -f /var/run/reboot-required ]; then
    printf 'Reboot required        : %bYES%b\n' "$YELLOW$BOLD" "$NC"
    REBOOT_STATUS="Reboot required"
else
    printf 'Reboot required        : %bNo%b\n' "$GREEN" "$NC"
    REBOOT_STATUS="No reboot required"
fi
printf '%b=========================================%b\n' "$BOLD$CYAN" "$NC"

if [ "$DRY_RUN" = true ]; then
    printf '\n%bDry run completed. No system changes or log writes were performed.%b\n' "$CYAN" "$NC"
else
    completion_status="completed successfully"
    if [ "$WARNINGS" -gt 0 ]; then
        completion_status="completed with $WARNINGS warning(s)"
    fi

    log_message="$(date '+%Y-%m-%d %H:%M:%S %z') - System update $completion_status; root space gained: $HUMAN_PART_SAVED; $REBOOT_STATUS."
    printf '%s\n' "$log_message" >>"$LOG_FILE" || warn "Could not write to $LOG_FILE."

    printf '\n%bLinux system maintenance %s.%b\n' "$GREEN" "$completion_status" "$NC"
    send_notification "Maintenance $completion_status. $HUMAN_PART_SAVED recovered. $REBOOT_STATUS."
fi
