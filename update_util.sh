#!/bin/sh
# System Update Utility - Ubuntu/Debian
# Safe system updates, package repair, cleanup, reporting, and optional notifications.

SCRIPT_VERSION="3.1.0"
AUTO_YES=false
DRY_RUN=false
NOTIFY=false
CLEAR_CACHE=false
CLEAR_HISTORY=false
FULL_UPGRADE=false
DOCKER_CLEANUP=false
DOCKER_LOGS_TRUNCATE=false
DOCKER_LOG_THRESHOLD_RAW="100M"
DOCKER_LOG_ROTATION=false
DOCKER_LOG_MAX_SIZE="50m"
DOCKER_LOG_MAX_FILE="3"
DOCKER_LOG_SCAN=""
COLOR_ENABLED=true
LOCK_DIR="/run/lock/system-update-utility.lock"
LOG_FILE="/var/log/sysupdate.log"
WARNINGS=0

show_help() {
    cat <<USAGE
Usage: sudo ./update_util.sh [OPTIONS]

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
      --docker-logs-truncate[=SIZE]
                         Empty container log files larger than SIZE
                         (default 100M; accepts K, M, G suffixes)
      --docker-log-rotation
                         Add log rotation (max-size 50m, max-file 3) to the
                         Docker daemon config; applies to new containers only
      --no-color         Disable coloured terminal output

Examples:
  sudo ./update_util.sh
  sudo ./update_util.sh --yes --full-upgrade
  sudo ./update_util.sh --dry-run --clear-cache
  sudo ./update_util.sh --yes --docker-cleanup
  sudo ./update_util.sh --docker-logs-truncate=200M --docker-log-rotation

Safety notes:
  --yes only affects APT confirmations. It does not automatically enable
  cache deletion, terminal-history deletion, Docker cleanup, Docker log
  truncation, or Docker daemon configuration changes.

Docker logs:
  Container log sizes are always reported (read-only). Truncation permanently
  discards old log lines. The daemon is never restarted automatically.
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
        --docker-logs-truncate)
            DOCKER_LOGS_TRUNCATE=true
            ;;
        --docker-logs-truncate=*)
            DOCKER_LOGS_TRUNCATE=true
            DOCKER_LOG_THRESHOLD_RAW=${1#*=}
            ;;
        --docker-log-rotation)
            DOCKER_LOG_ROTATION=true
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

# ---------------------------------------------------------------------------
# Docker container log helpers
# ---------------------------------------------------------------------------

# Convert a size such as 100M, 1G, 512k or 1048576 into bytes.
parse_size_bytes() {
    size_value=$(printf '%s' "$1" | tr '[:lower:]' '[:upper:]')
    size_value=${size_value%B}
    case "$size_value" in
        ''|[!0-9]*|*[!0-9KMGT]*|*[KMGT]?*) return 1 ;;
    esac
    case "$size_value" in
        *[KMGT])
            command_exists numfmt || return 1
            numfmt --from=iec "$size_value" 2>/dev/null
            ;;
        *)
            printf '%s\n' "$size_value"
            ;;
    esac
}

docker_daemon_json_path() {
    case "$(command -v docker)" in
        /snap/*) printf '/var/snap/docker/current/config/daemon.json\n' ;;
        *) printf '/etc/docker/daemon.json\n' ;;
    esac
}

docker_restart_hint() {
    case "$(command -v docker)" in
        /snap/*) printf 'sudo snap restart docker\n' ;;
        *) printf 'sudo systemctl restart docker\n' ;;
    esac
}

# Write "<active-bytes> <total-bytes> <container> <log-path>" lines, largest
# first, to $DOCKER_LOG_SCAN. Total includes rotated files (<log>.1, ...).
scan_docker_logs() {
    DOCKER_LOG_UNREADABLE=0
    : >"$DOCKER_LOG_SCAN"

    container_ids=$(docker ps -aq 2>/dev/null || true)
    [ -n "$container_ids" ] || return 0

    # shellcheck disable=SC2086 # container IDs are split into arguments on purpose
    inspect_output=$(docker inspect --format '{{.Name}} {{.LogPath}}' $container_ids 2>/dev/null || true)
    scan_unsorted=$(mktemp)

    while read -r container_name log_path; do
        # Drivers such as journald or syslog keep no local log file.
        [ -n "$log_path" ] || continue
        container_name=${container_name#/}

        active_bytes=$(stat -c %s "$log_path" 2>/dev/null || printf '')
        if [ -z "$active_bytes" ]; then
            DOCKER_LOG_UNREADABLE=$((DOCKER_LOG_UNREADABLE + 1))
            continue
        fi

        total_bytes=$active_bytes
        for rotated_file in "$log_path".*; do
            [ -f "$rotated_file" ] || continue
            rotated_bytes=$(stat -c %s "$rotated_file" 2>/dev/null || printf '0')
            total_bytes=$((total_bytes + rotated_bytes))
        done

        printf '%s %s %s %s\n' "$active_bytes" "$total_bytes" "$container_name" "$log_path" >>"$scan_unsorted"
    done <<EOF
$inspect_output
EOF

    sort -k2,2nr "$scan_unsorted" >"$DOCKER_LOG_SCAN"
    rm -f "$scan_unsorted"
}

# Print the configured json-file max-size from daemon.json, if any.
daemon_json_max_size() {
    daemon_json=$1
    [ -s "$daemon_json" ] || return 0
    if command_exists python3; then
        python3 -c 'import json,sys
try:
    data = json.load(open(sys.argv[1]))
    print((data.get("log-opts") or {}).get("max-size", ""))
except Exception:
    pass' "$daemon_json" 2>/dev/null || true
    elif command_exists jq; then
        jq -r '."log-opts"."max-size" // empty' "$daemon_json" 2>/dev/null || true
    else
        sed -n 's/.*"max-size"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$daemon_json" | head -n 1
    fi
}

# Merge log rotation settings into a copy of daemon.json.
# Exit codes: 0 merged into $2, 2 no JSON tool, 3 invalid JSON,
#             4 a non-json-file log driver is configured, 5 already configured.
merge_daemon_json() {
    source_json=$1
    merged_json=$2

    if command_exists python3; then
        python3 -c 'import json, os, sys
src, out, max_size, max_file = sys.argv[1:5]
data = {}
if os.path.isfile(src) and os.path.getsize(src) > 0:
    try:
        data = json.load(open(src))
    except ValueError:
        sys.exit(3)
if not isinstance(data, dict):
    sys.exit(3)
if data.get("log-driver", "json-file") != "json-file":
    sys.exit(4)
opts = data.get("log-opts") or {}
if not isinstance(opts, dict):
    sys.exit(3)
if "max-size" in opts:
    sys.exit(5)
opts["max-size"] = max_size
opts.setdefault("max-file", max_file)
data["log-opts"] = opts
with open(out, "w") as handle:
    json.dump(data, handle, indent=2)
    handle.write("\n")' "$source_json" "$merged_json" "$DOCKER_LOG_MAX_SIZE" "$DOCKER_LOG_MAX_FILE"
        return $?
    fi

    if command_exists jq; then
        if [ -s "$source_json" ]; then
            jq_input=$source_json
        else
            jq_input=$(mktemp)
            printf '{}\n' >"$jq_input"
        fi
        if ! jq -e 'type == "object"' "$jq_input" >/dev/null 2>&1; then
            return 3
        fi
        if [ "$(jq -r '."log-driver" // "json-file"' "$jq_input")" != "json-file" ]; then
            return 4
        fi
        if [ -n "$(jq -r '."log-opts"."max-size" // empty' "$jq_input")" ]; then
            return 5
        fi
        jq --arg size "$DOCKER_LOG_MAX_SIZE" --arg files "$DOCKER_LOG_MAX_FILE" \
            '."log-opts" = ({"max-file": $files} + (."log-opts" // {}) + {"max-size": $size})' \
            "$jq_input" >"$merged_json" || return 3
        [ "$jq_input" = "$source_json" ] || rm -f "$jq_input"
        return 0
    fi

    return 2
}

configure_docker_log_rotation() {
    daemon_json=$(docker_daemon_json_path)
    merged_json=$(mktemp)

    merge_status=0
    merge_daemon_json "$daemon_json" "$merged_json" || merge_status=$?

    case "$merge_status" in
        0) ;;
        2)
            warn "python3 or jq is required to edit $daemon_json safely; log rotation was not configured."
            rm -f "$merged_json"; return 0 ;;
        3)
            warn "$daemon_json is not valid JSON; it was left unchanged."
            rm -f "$merged_json"; return 0 ;;
        4)
            printf 'A non-json-file log driver is set in %s; leaving it unchanged.\n' "$daemon_json"
            rm -f "$merged_json"; return 0 ;;
        5)
            printf 'Log rotation is already configured in %s; leaving it unchanged.\n' "$daemon_json"
            rm -f "$merged_json"; return 0 ;;
        *)
            warn "Could not prepare a new $daemon_json; it was left unchanged."
            rm -f "$merged_json"; return 0 ;;
    esac

    # Docker 23+ can validate a config file without touching the daemon.
    if command_exists dockerd && dockerd --help 2>&1 | grep -q -- '--validate'; then
        if ! dockerd --validate --config-file="$merged_json" >/dev/null 2>&1; then
            warn "dockerd rejected the new configuration; $daemon_json was left unchanged."
            rm -f "$merged_json"
            return 0
        fi
    fi

    if [ "$DRY_RUN" = true ]; then
        if [ -f "$daemon_json" ]; then
            printf '%b[DRY RUN]%b Back up %s to %s.bak.<timestamp>\n' "$CYAN" "$NC" "$daemon_json" "$daemon_json"
        fi
        printf '%b[DRY RUN]%b Write %s:\n' "$CYAN" "$NC" "$daemon_json"
        sed 's/^/    /' "$merged_json"
        rm -f "$merged_json"
        return 0
    fi

    mkdir -p "$(dirname "$daemon_json")"
    if [ -f "$daemon_json" ]; then
        backup_path="$daemon_json.bak.$(date '+%Y%m%d%H%M%S')"
        cp -p "$daemon_json" "$backup_path"
        printf 'Backed up %s to %s\n' "$daemon_json" "$backup_path"
    fi

    staged_json="$daemon_json.tmp.$$"
    cp "$merged_json" "$staged_json"
    chmod 644 "$staged_json"
    mv "$staged_json" "$daemon_json"
    rm -f "$merged_json"

    DOCKER_ROTATION_STATE="pending-restart"
    printf '%bLog rotation (max-size %s, max-file %s) written to %s.%b\n' \
        "$GREEN" "$DOCKER_LOG_MAX_SIZE" "$DOCKER_LOG_MAX_FILE" "$daemon_json" "$NC"
    printf 'The Docker daemon was NOT restarted. When convenient, run:\n'
    printf '    %s\n' "$(docker_restart_hint)"
    printf 'Existing containers keep their old settings until they are recreated,\n'
    printf 'for example with: docker compose up -d --force-recreate\n'
}

truncate_large_docker_logs() {
    while read -r active_bytes _total container_name log_path; do
        [ "$active_bytes" -gt "$DOCKER_LOG_THRESHOLD" ] || continue

        if [ "$DRY_RUN" = true ]; then
            printf '%b[DRY RUN]%b truncate -s 0 %s  (%s, %s)\n' "$CYAN" "$NC" \
                "$log_path" "$container_name" "$(human_bytes "$active_bytes")"
            DOCKER_LOG_FREED=$((DOCKER_LOG_FREED + active_bytes))
        elif truncate -s 0 "$log_path" 2>/dev/null; then
            printf 'Truncated log for %s (%s freed)\n' "$container_name" "$(human_bytes "$active_bytes")"
            DOCKER_LOG_FREED=$((DOCKER_LOG_FREED + active_bytes))
        else
            warn "Could not truncate the log for container $container_name ($log_path)."
        fi
    done <"$DOCKER_LOG_SCAN"
}

cleanup_lock() {
    if [ "${LOCK_ACQUIRED:-false}" = true ]; then
        rmdir "$LOCK_DIR" 2>/dev/null || true
    fi
    if [ -n "$DOCKER_LOG_SCAN" ]; then
        rm -f "$DOCKER_LOG_SCAN" 2>/dev/null || true
    fi
}

trap cleanup_lock EXIT HUP INT TERM

# Root privileges are required only for real maintenance operations.
# Dry-run mode performs no system modifications and is safe for CI/non-root use.
if [ "$DRY_RUN" = false ] && [ "$(id -u)" -ne 0 ]; then
    fatal "Run this script as root, for example: sudo ./update_util.sh"
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

DOCKER_LOG_THRESHOLD=$(parse_size_bytes "$DOCKER_LOG_THRESHOLD_RAW" || printf '')
case "$DOCKER_LOG_THRESHOLD" in
    ''|*[!0-9]*|0) fatal "Invalid size for --docker-logs-truncate: '$DOCKER_LOG_THRESHOLD_RAW' (examples: 100M, 1G)." ;;
esac
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
        run_command docker system prune --volumes -f || warn "Docker cleanup failed."
    else
        printf 'Skipping Docker cleanup. Use --docker-cleanup to enable it.\n'
    fi
else
    printf 'Docker is not installed; Docker cleanup was skipped.\n'
fi

DOCKER_LOGS_CHECKED=false
DOCKER_LOG_FREED=0
DOCKER_LOG_TOTAL=0
DOCKER_LOG_COUNT=0
DOCKER_LOG_OVER=0
DOCKER_LOG_UNREADABLE=0
DOCKER_ROTATION_STATE="unknown"

if command_exists docker; then
    if docker info >/dev/null 2>&1; then
        info "Checking Docker container log sizes..."
        DOCKER_LOGS_CHECKED=true
        DOCKER_LOG_SCAN=$(mktemp)
        scan_docker_logs

        DOCKER_LOG_COUNT=$(awk 'END {print NR}' "$DOCKER_LOG_SCAN")
        DOCKER_LOG_TOTAL=$(awk '{sum += $2} END {printf "%d\n", sum}' "$DOCKER_LOG_SCAN")
        DOCKER_LOG_OVER=$(awk -v limit="$DOCKER_LOG_THRESHOLD" '$1 > limit {n++} END {print n + 0}' "$DOCKER_LOG_SCAN")

        if [ "$DOCKER_LOG_COUNT" -gt 0 ]; then
            printf 'Largest container logs:\n'
            head -n 5 "$DOCKER_LOG_SCAN" | while read -r _active total_bytes container_name _path; do
                printf '    %-10s %s\n' "$(human_bytes "$total_bytes")" "$container_name"
            done
        elif [ "$DOCKER_LOG_UNREADABLE" -gt 0 ]; then
            printf 'Container log files are not readable without root; sizes were not measured.\n'
        else
            printf 'No container log files found.\n'
        fi

        logging_driver=$(docker info --format '{{.LoggingDriver}}' 2>/dev/null || printf 'unknown')
        if [ "$logging_driver" != "json-file" ]; then
            DOCKER_ROTATION_STATE="driver:$logging_driver"
        elif [ -n "$(daemon_json_max_size "$(docker_daemon_json_path)")" ]; then
            DOCKER_ROTATION_STATE="configured"
        else
            DOCKER_ROTATION_STATE="missing"
        fi

        if [ "$DOCKER_LOGS_TRUNCATE" = true ]; then
            info "Truncating Docker container logs larger than $(human_bytes "$DOCKER_LOG_THRESHOLD")..."
            if [ "$DOCKER_LOG_OVER" -gt 0 ]; then
                truncate_large_docker_logs
            elif [ "$DOCKER_LOG_COUNT" -eq 0 ] && [ "$DOCKER_LOG_UNREADABLE" -gt 0 ]; then
                printf 'Log sizes could not be measured without root; nothing was truncated.\n'
            else
                printf 'No container logs exceed the threshold.\n'
            fi
        elif [ "$DOCKER_LOG_OVER" -gt 0 ]; then
            warn "$DOCKER_LOG_OVER container log file(s) exceed $(human_bytes "$DOCKER_LOG_THRESHOLD"). Use --docker-logs-truncate to empty them."
        fi

        if [ "$DOCKER_LOG_ROTATION" = true ]; then
            info "Configuring Docker log rotation..."
            if [ "$DOCKER_ROTATION_STATE" = "missing" ]; then
                configure_docker_log_rotation
            elif [ "$DOCKER_ROTATION_STATE" = "configured" ]; then
                printf 'Log rotation is already configured; nothing to change.\n'
            else
                printf 'The daemon uses the "%s" log driver; json-file rotation does not apply.\n' "$logging_driver"
            fi
        fi
    else
        printf 'Docker daemon is not reachable; Docker log checks were skipped.\n'
    fi
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

DOCKER_LOG_SAVED=0
if [ "$DRY_RUN" = false ]; then
    DOCKER_LOG_SAVED=$DOCKER_LOG_FREED
fi

TOTAL_SAVED=$((APT_DIFF + APP_DIFF + JOURNAL_DIFF + DOCKER_LOG_SAVED))
HUMAN_TOTAL=$(human_bytes "$TOTAL_SAVED")
HUMAN_PART_SAVED=$(human_bytes "$PART_CLEARED")

printf '\n%b========== MAINTENANCE SUMMARY ==========%b\n' "$BOLD$CYAN" "$NC"
printf 'APT cache cleared      : %b%s%b\n' "$BOLD" "$(human_bytes "$APT_DIFF")" "$NC"
printf 'Selected app caches    : %b%s%b\n' "$BOLD" "$(human_bytes "$APP_DIFF")" "$NC"
printf 'Journal logs cleared   : %b%s%b\n' "$BOLD" "$(human_bytes "$JOURNAL_DIFF")" "$NC"
if [ "$DOCKER_LOGS_TRUNCATE" = true ] && [ "$DOCKER_LOGS_CHECKED" = true ]; then
    if [ "$DRY_RUN" = true ]; then
        printf 'Docker logs truncated  : %b%s (would free)%b\n' "$BOLD" "$(human_bytes "$DOCKER_LOG_FREED")" "$NC"
    else
        printf 'Docker logs truncated  : %b%s%b\n' "$BOLD" "$(human_bytes "$DOCKER_LOG_FREED")" "$NC"
    fi
fi
if [ "$DOCKER_LOGS_CHECKED" = true ]; then
    if [ "$DOCKER_LOG_COUNT" -gt 0 ]; then
        largest_log=$(head -n 1 "$DOCKER_LOG_SCAN" | while read -r _active total_bytes container_name _path; do
            printf '%s %s' "$container_name" "$(human_bytes "$total_bytes")"
        done)
        printf 'Docker container logs  : %b%s%b in %s container(s) (largest: %s)\n' \
            "$BOLD" "$(human_bytes "$DOCKER_LOG_TOTAL")" "$NC" "$DOCKER_LOG_COUNT" "$largest_log"
    elif [ "$DOCKER_LOG_UNREADABLE" -gt 0 ]; then
        printf 'Docker container logs  : unknown (run as root to measure)\n'
    else
        printf 'Docker container logs  : none\n'
    fi

    case "$DOCKER_ROTATION_STATE" in
        configured)
            printf 'Docker log rotation    : %bconfigured%b\n' "$GREEN" "$NC" ;;
        pending-restart)
            printf 'Docker log rotation    : %bconfigured, restart Docker to apply%b\n' "$YELLOW$BOLD" "$NC" ;;
        missing)
            printf 'Docker log rotation    : %bNOT configured%b (use --docker-log-rotation)\n' "$YELLOW$BOLD" "$NC" ;;
        driver:*)
            printf 'Docker log rotation    : n/a (%s driver)\n' "${DOCKER_ROTATION_STATE#driver:}" ;;
    esac
fi
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
