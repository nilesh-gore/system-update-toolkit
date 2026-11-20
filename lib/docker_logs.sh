# shellcheck shell=sh disable=SC2016
# (SC2016: single-quoted sh -c / python3 -c / jq programs are intentional.)
# ==============================================================================
# System Update Toolkit - Docker container log management (shared library)
# ==============================================================================
# Sourced by the Unix update scripts. Docker's default json-file log driver
# never rotates logs, so long-running containers can fill the disk, and
# `docker system prune` does not touch logs of running containers.
#
# Public interface:
#   docker_logs_parse_arg ARG   Consume a --docker-log* option (returns 1 if ARG is not one)
#   docker_logs_help            Print help lines for the options
#   docker_logs_validate        Validate option values (exits on error)
#   docker_logs_run [HEADER]    Report log sizes, optionally truncate / configure rotation
#   docker_logs_summary [WIDTH] Print summary lines (label column WIDTH, default 22)
#
# After docker_logs_run, DOCKER_LOG_SAVED holds the bytes freed by truncation
# (0 in dry-run mode) so callers can add it to their totals.
#
# Optional caller-provided names: warn (function), DRY_RUN, BLUE, CYAN, GREEN,
# YELLOW, BOLD, NC. Works whether the caller runs as root or uses sudo.
# ==============================================================================

DOCKER_LOGS_TRUNCATE=false
DOCKER_LOG_THRESHOLD_RAW="100M"
DOCKER_LOG_THRESHOLD=104857600
DOCKER_LOG_ROTATION=false
DOCKER_LOG_MAX_SIZE="50m"
DOCKER_LOG_MAX_FILE="3"

DOCKER_LOGS_CHECKED=false
DOCKER_LOGS_IN_VM=false
DOCKER_LOG_SCAN=""
DOCKER_LOG_COUNT=0
DOCKER_LOG_TOTAL=0
DOCKER_LOG_OVER=0
DOCKER_LOG_UNREADABLE=0
DOCKER_LOG_LARGEST=""
DOCKER_LOG_FREED=0
DOCKER_LOG_SAVED=0
DOCKER_CONTAINERS=0
DOCKER_UNLIMITED=0
DOCKER_LOGGING_DRIVER="unknown"
DOCKER_ROTATION_STATE="unknown"

# ---------------------------------------------------------------------------
# Internal helpers
# ---------------------------------------------------------------------------

_dl_has() {
    command -v "$1" >/dev/null 2>&1
}

_dl_is_dry_run() {
    [ "${DRY_RUN:-false}" = true ]
}

_dl_step() {
    printf '%b==>%b %b%s%b\n' "${BLUE:-}" "${NC:-}" "${BOLD:-}" "$1" "${NC:-}"
}

_dl_dry() {
    printf '%b[DRY RUN]%b %s\n' "${CYAN:-}" "${NC:-}" "$1"
}

_dl_warn() {
    if command -v warn >/dev/null 2>&1; then
        warn "$1"
    else
        printf '%bWARNING:%b %s\n' "${YELLOW:-}" "${NC:-}" "$1" >&2
    fi
}

# Portable (Linux + macOS) human-readable byte count.
_dl_human() {
    awk -v bytes="${1:-0}" 'BEGIN {
        split("B K M G T", unit, " ")
        i = 1
        while (bytes >= 1024 && i < 5) { bytes /= 1024; i++ }
        if (i == 1) printf "%d%s\n", bytes, unit[i]
        else printf "%.1f%s\n", bytes, unit[i]
    }'
}

# Run a read-only command, retrying with non-interactive sudo if needed.
_dl_read_priv() {
    if "$@" 2>/dev/null; then
        return 0
    fi
    if [ "$(id -u)" -ne 0 ] && _dl_has sudo; then
        sudo -n "$@" 2>/dev/null
        return $?
    fi
    return 1
}

# Run a modifying command as root (via sudo when not already root).
_dl_write_priv() {
    if [ "$(id -u)" -eq 0 ] || ! _dl_has sudo; then
        "$@"
    else
        sudo "$@"
    fi
}

# Convert 100M, 1g, 512k, 100MB or 1048576 into bytes (no numfmt needed).
_dl_parse_size() {
    _dl_value=$(printf '%s' "$1" | tr '[:lower:]' '[:upper:]')
    _dl_value=${_dl_value%B}
    case "$_dl_value" in
        ''|[!0-9]*|*[!0-9KMGT]*|*[KMGT]?*) return 1 ;;
    esac
    _dl_multiplier=1
    case "$_dl_value" in
        *K) _dl_multiplier=1024 ;;
        *M) _dl_multiplier=1048576 ;;
        *G) _dl_multiplier=1073741824 ;;
        *T) _dl_multiplier=1099511627776 ;;
    esac
    _dl_number=$(printf '%s' "$_dl_value" | sed 's/[KMGT]$//; s/^0*//')
    [ -n "$_dl_number" ] || _dl_number=0
    printf '%s\n' "$((_dl_number * _dl_multiplier))"
}

_dl_daemon_json_path() {
    case "$(command -v docker)" in
        /snap/*) printf '/var/snap/docker/current/config/daemon.json\n' ;;
        *) printf '/etc/docker/daemon.json\n' ;;
    esac
}

_dl_restart_hint() {
    case "$(command -v docker)" in
        /snap/*) printf 'sudo snap restart docker\n' ;;
        *) printf 'sudo systemctl restart docker\n' ;;
    esac
}

# Docker Desktop (macOS/Windows/Linux) and macOS VMs such as Colima keep
# container logs inside a VM, out of reach of the host.
_dl_detect_vm() {
    DOCKER_LOGS_IN_VM=false
    if [ "$(uname -s)" = "Darwin" ]; then
        DOCKER_LOGS_IN_VM=true
        return 0
    fi
    case "$(docker info --format '{{.OperatingSystem}}' 2>/dev/null || true)" in
        *"Docker Desktop"*) DOCKER_LOGS_IN_VM=true ;;
    esac
}

# Writes "<active-bytes> <total-bytes> <container> <log-path>" lines, largest
# first, to $DOCKER_LOG_SCAN. Total includes rotated files (<log>.1, ...).
# Also counts containers using json-file without a max-size limit.
_dl_scan() {
    : >"$DOCKER_LOG_SCAN"
    _dl_ids=$(docker ps -aq 2>/dev/null || true)
    [ -n "$_dl_ids" ] || return 0

    # shellcheck disable=SC2086 # container IDs are split into arguments on purpose
    _dl_inspect=$(docker inspect --format \
        '{{.Name}}|{{.LogPath}}|{{.HostConfig.LogConfig.Type}}|{{index .HostConfig.LogConfig.Config "max-size"}}' \
        $_dl_ids 2>/dev/null || true)
    _dl_unsorted=$(mktemp)

    while IFS='|' read -r _dl_name _dl_path _dl_driver _dl_max; do
        [ -n "$_dl_name" ] || continue
        _dl_name=${_dl_name#/}
        DOCKER_CONTAINERS=$((DOCKER_CONTAINERS + 1))
        if [ "$_dl_driver" = "json-file" ] && [ -z "$_dl_max" ]; then
            DOCKER_UNLIMITED=$((DOCKER_UNLIMITED + 1))
        fi

        [ "$DOCKER_LOGS_IN_VM" = false ] || continue
        # Drivers such as journald or syslog keep no local log file.
        [ -n "$_dl_path" ] || continue

        _dl_sizes=$(_dl_read_priv sh -c '
            active=$(wc -c <"$1") || exit 1
            active=$((active)); total=$active
            for rotated in "$1".*; do
                [ -f "$rotated" ] || continue
                size=$(wc -c <"$rotated") && total=$((total + size))
            done
            echo "$active $total"' sh "$_dl_path" || true)

        if [ -z "$_dl_sizes" ]; then
            DOCKER_LOG_UNREADABLE=$((DOCKER_LOG_UNREADABLE + 1))
            continue
        fi
        printf '%s %s %s\n' "$_dl_sizes" "$_dl_name" "$_dl_path" >>"$_dl_unsorted"
    done <<EOF
$_dl_inspect
EOF

    sort -k2,2nr "$_dl_unsorted" >"$DOCKER_LOG_SCAN"
    rm -f "$_dl_unsorted"
}

# Print the configured json-file max-size from a daemon.json, if any.
_dl_daemon_max_size() {
    _dl_content=$(_dl_read_priv cat "$1" || true)
    [ -n "$_dl_content" ] || return 0
    if _dl_has python3; then
        printf '%s' "$_dl_content" | python3 -c 'import json, sys
try:
    print((json.load(sys.stdin).get("log-opts") or {}).get("max-size", ""))
except Exception:
    pass' 2>/dev/null || true
    elif _dl_has jq; then
        printf '%s' "$_dl_content" | jq -r '."log-opts"."max-size" // empty' 2>/dev/null || true
    else
        printf '%s' "$_dl_content" | sed -n 's/.*"max-size"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -n 1
    fi
}

# Merge rotation settings from SOURCE (plain readable copy) into MERGED.
# Returns: 0 merged, 2 no JSON tool, 3 invalid JSON, 4 other log driver,
#          5 max-size already set.
_dl_merge_daemon_json() {
    _dl_src=$1
    _dl_out=$2

    if _dl_has python3; then
        python3 -c 'import json, os, sys
src, out, max_size, max_file = sys.argv[1:5]
data = {}
if os.path.getsize(src) > 0:
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
    handle.write("\n")' "$_dl_src" "$_dl_out" "$DOCKER_LOG_MAX_SIZE" "$DOCKER_LOG_MAX_FILE"
        return $?
    fi

    if _dl_has jq; then
        [ -s "$_dl_src" ] || printf '{}\n' >"$_dl_src"
        jq -e 'type == "object"' "$_dl_src" >/dev/null 2>&1 || return 3
        [ "$(jq -r '."log-driver" // "json-file"' "$_dl_src")" = "json-file" ] || return 4
        [ -z "$(jq -r '."log-opts"."max-size" // empty' "$_dl_src")" ] || return 5
        jq --arg size "$DOCKER_LOG_MAX_SIZE" --arg files "$DOCKER_LOG_MAX_FILE" \
            '."log-opts" = ({"max-file": $files} + (."log-opts" // {}) + {"max-size": $size})' \
            "$_dl_src" >"$_dl_out" || return 3
        return 0
    fi

    return 2
}

_dl_configure_rotation() {
    _dl_daemon_json=$(_dl_daemon_json_path)
    _dl_current=$(mktemp)
    _dl_merged=$(mktemp)

    _dl_exists=false
    if _dl_read_priv test -f "$_dl_daemon_json"; then
        _dl_exists=true
        if ! _dl_read_priv cat "$_dl_daemon_json" >"$_dl_current"; then
            _dl_warn "Cannot read $_dl_daemon_json; log rotation was not configured."
            rm -f "$_dl_current" "$_dl_merged"
            return 0
        fi
    fi

    _dl_status=0
    _dl_merge_daemon_json "$_dl_current" "$_dl_merged" || _dl_status=$?
    rm -f "$_dl_current"

    case "$_dl_status" in
        0) ;;
        2) _dl_warn "python3 or jq is required to edit $_dl_daemon_json safely; log rotation was not configured." ;;
        3) _dl_warn "$_dl_daemon_json is not valid JSON; it was left unchanged." ;;
        4) printf 'A non-json-file log driver is set in %s; leaving it unchanged.\n' "$_dl_daemon_json" ;;
        5) printf 'Log rotation is already configured in %s; leaving it unchanged.\n' "$_dl_daemon_json" ;;
        *) _dl_warn "Could not prepare a new $_dl_daemon_json; it was left unchanged." ;;
    esac
    if [ "$_dl_status" -ne 0 ]; then
        rm -f "$_dl_merged"
        return 0
    fi

    # Docker 23+ can validate a config file without touching the daemon.
    if _dl_has dockerd && dockerd --help 2>&1 | grep -q -- '--validate'; then
        if ! dockerd --validate --config-file="$_dl_merged" >/dev/null 2>&1; then
            _dl_warn "dockerd rejected the new configuration; $_dl_daemon_json was left unchanged."
            rm -f "$_dl_merged"
            return 0
        fi
    fi

    if _dl_is_dry_run; then
        if [ "$_dl_exists" = true ]; then
            _dl_dry "Back up $_dl_daemon_json to $_dl_daemon_json.bak.<timestamp>"
        fi
        _dl_dry "Write $_dl_daemon_json:"
        sed 's/^/    /' "$_dl_merged"
        rm -f "$_dl_merged"
        return 0
    fi

    _dl_write_priv mkdir -p "$(dirname "$_dl_daemon_json")"
    if [ "$_dl_exists" = true ]; then
        _dl_backup="$_dl_daemon_json.bak.$(date '+%Y%m%d%H%M%S')"
        _dl_write_priv cp -p "$_dl_daemon_json" "$_dl_backup"
        printf 'Backed up %s to %s\n' "$_dl_daemon_json" "$_dl_backup"
    fi
    _dl_staged="$_dl_daemon_json.tmp.$$"
    _dl_write_priv cp "$_dl_merged" "$_dl_staged"
    _dl_write_priv chmod 644 "$_dl_staged"
    _dl_write_priv mv "$_dl_staged" "$_dl_daemon_json"
    rm -f "$_dl_merged"

    DOCKER_ROTATION_STATE="pending-restart"
    printf '%bLog rotation (max-size %s, max-file %s) written to %s.%b\n' \
        "${GREEN:-}" "$DOCKER_LOG_MAX_SIZE" "$DOCKER_LOG_MAX_FILE" "$_dl_daemon_json" "${NC:-}"
    printf 'The Docker daemon was NOT restarted. When convenient, run:\n'
    printf '    %s\n' "$(_dl_restart_hint)"
    printf 'Existing containers keep their old settings until they are recreated,\n'
    printf 'for example with: docker compose up -d --force-recreate\n'
}

_dl_print_desktop_rotation_hint() {
    printf 'Docker Desktop keeps its daemon config inside its VM. To limit log size, open\n'
    printf 'Docker Desktop > Settings > Docker Engine, add the following, then Apply & restart:\n'
    printf '    "log-opts": { "max-size": "%s", "max-file": "%s" }\n' "$DOCKER_LOG_MAX_SIZE" "$DOCKER_LOG_MAX_FILE"
    printf '(Colima: run "colima start --edit" and add the same keys under docker:.)\n'
}

_dl_truncate_large() {
    while read -r _dl_active _ _dl_name _dl_path; do
        [ "$_dl_active" -gt "$DOCKER_LOG_THRESHOLD" ] || continue

        if _dl_is_dry_run; then
            _dl_dry "truncate -s 0 $_dl_path  ($_dl_name, $(_dl_human "$_dl_active"))"
            DOCKER_LOG_FREED=$((DOCKER_LOG_FREED + _dl_active))
        elif _dl_write_priv truncate -s 0 "$_dl_path" 2>/dev/null; then
            printf 'Truncated log for %s (%s freed)\n' "$_dl_name" "$(_dl_human "$_dl_active")"
            DOCKER_LOG_FREED=$((DOCKER_LOG_FREED + _dl_active))
        else
            _dl_warn "Could not truncate the log for container $_dl_name ($_dl_path)."
        fi
    done <"$DOCKER_LOG_SCAN"
}

# ---------------------------------------------------------------------------
# Public interface
# ---------------------------------------------------------------------------

docker_logs_parse_arg() {
    case "$1" in
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
        *)
            return 1
            ;;
    esac
}

docker_logs_help() {
    cat <<'HELP'
  --docker-logs-truncate[=SIZE]
                         Empty container log files larger than SIZE
                         (default 100M; accepts K, M, G suffixes)
  --docker-log-rotation
                         Add log rotation (max-size 50m, max-file 3) to the
                         Docker daemon config; applies to new containers only
HELP
}

docker_logs_validate() {
    DOCKER_LOG_THRESHOLD=$(_dl_parse_size "$DOCKER_LOG_THRESHOLD_RAW" || printf '')
    case "$DOCKER_LOG_THRESHOLD" in
        ''|*[!0-9]*|0)
            printf 'ERROR: Invalid size for --docker-logs-truncate: %s (examples: 100M, 1G).\n' \
                "'$DOCKER_LOG_THRESHOLD_RAW'" >&2
            exit 1
            ;;
    esac
}

docker_logs_run() {
    _dl_has docker || return 0
    if ! docker info >/dev/null 2>&1; then
        printf 'Docker daemon is not reachable; Docker log checks were skipped.\n'
        return 0
    fi

    _dl_step "${1:-Checking Docker container logs...}"
    DOCKER_LOGS_CHECKED=true
    _dl_detect_vm
    DOCKER_LOG_SCAN=$(mktemp)
    _dl_scan

    DOCKER_LOG_COUNT=$(awk 'END {print NR}' "$DOCKER_LOG_SCAN")
    DOCKER_LOG_TOTAL=$(awk '{sum += $2} END {printf "%d\n", sum}' "$DOCKER_LOG_SCAN")
    DOCKER_LOG_OVER=$(awk -v limit="$DOCKER_LOG_THRESHOLD" '$1 > limit {n++} END {print n + 0}' "$DOCKER_LOG_SCAN")
    DOCKER_LOG_LARGEST=$(awk 'NR == 1 {print $3, $2}' "$DOCKER_LOG_SCAN")

    if [ "$DOCKER_LOGS_IN_VM" = true ]; then
        printf 'Container logs live inside the Docker Desktop/VM disk; sizes cannot be measured from the host.\n'
    elif [ "$DOCKER_LOG_COUNT" -gt 0 ]; then
        printf 'Largest container logs:\n'
        head -n 5 "$DOCKER_LOG_SCAN" | while read -r _ _dl_total _dl_name _; do
            printf '    %-8s %s\n' "$(_dl_human "$_dl_total")" "$_dl_name"
        done
    elif [ "$DOCKER_LOG_UNREADABLE" -gt 0 ]; then
        printf 'Container log files are not readable without root; sizes were not measured.\n'
    elif [ "$DOCKER_CONTAINERS" -eq 0 ]; then
        printf 'No containers found.\n'
    else
        printf 'No container log files found.\n'
    fi

    DOCKER_LOGGING_DRIVER=$(docker info --format '{{.LoggingDriver}}' 2>/dev/null || printf 'unknown')
    if [ "$DOCKER_LOGGING_DRIVER" != "json-file" ]; then
        DOCKER_ROTATION_STATE="driver"
    elif [ "$DOCKER_LOGS_IN_VM" = true ]; then
        DOCKER_ROTATION_STATE="vm"
    elif [ -n "$(_dl_daemon_max_size "$(_dl_daemon_json_path)")" ]; then
        DOCKER_ROTATION_STATE="configured"
    else
        DOCKER_ROTATION_STATE="missing"
    fi

    if [ "$DOCKER_LOGS_TRUNCATE" = true ]; then
        _dl_step "Truncating Docker container logs larger than $(_dl_human "$DOCKER_LOG_THRESHOLD")..."
        if [ "$DOCKER_LOGS_IN_VM" = true ]; then
            printf 'Logs inside Docker Desktop/VM cannot be truncated from the host; recreate the\n'
            printf 'container (docker compose up -d --force-recreate) to start with an empty log.\n'
        elif [ "$DOCKER_LOG_OVER" -gt 0 ]; then
            _dl_truncate_large
        elif [ "$DOCKER_LOG_COUNT" -eq 0 ] && [ "$DOCKER_LOG_UNREADABLE" -gt 0 ]; then
            printf 'Log sizes could not be measured without root; nothing was truncated.\n'
        else
            printf 'No container logs exceed the threshold.\n'
        fi
    elif [ "$DOCKER_LOG_OVER" -gt 0 ]; then
        _dl_warn "$DOCKER_LOG_OVER container log file(s) exceed $(_dl_human "$DOCKER_LOG_THRESHOLD"). Use --docker-logs-truncate to empty them."
    fi

    if [ "$DOCKER_LOG_ROTATION" = true ]; then
        _dl_step "Configuring Docker log rotation..."
        case "$DOCKER_ROTATION_STATE" in
            missing) _dl_configure_rotation ;;
            vm) _dl_print_desktop_rotation_hint ;;
            configured) printf 'Log rotation is already configured; nothing to change.\n' ;;
            *) printf 'The daemon uses the "%s" log driver; json-file rotation does not apply.\n' "$DOCKER_LOGGING_DRIVER" ;;
        esac
    fi

    rm -f "$DOCKER_LOG_SCAN"
    DOCKER_LOG_SCAN=""
    if ! _dl_is_dry_run; then
        # shellcheck disable=SC2034 # read by the calling scripts
        DOCKER_LOG_SAVED=$DOCKER_LOG_FREED
    fi
}

docker_logs_summary() {
    [ "$DOCKER_LOGS_CHECKED" = true ] || return 0
    _dl_width=${1:-22}

    if [ "$DOCKER_LOGS_TRUNCATE" = true ] && [ "$DOCKER_LOGS_IN_VM" = false ]; then
        _dl_suffix=""
        _dl_is_dry_run && _dl_suffix=" (would free)"
        printf "%-${_dl_width}s: %b%s%s%b\n" "Docker logs truncated" "${BOLD:-}" \
            "$(_dl_human "$DOCKER_LOG_FREED")" "$_dl_suffix" "${NC:-}"
    fi

    if [ "$DOCKER_LOGS_IN_VM" = true ]; then
        _dl_logs_text="inside Docker Desktop/VM (not measurable)"
    elif [ "$DOCKER_LOG_COUNT" -gt 0 ]; then
        _dl_largest_name=${DOCKER_LOG_LARGEST% *}
        _dl_largest_bytes=${DOCKER_LOG_LARGEST##* }
        _dl_logs_text="$(_dl_human "$DOCKER_LOG_TOTAL") in $DOCKER_LOG_COUNT container(s) (largest: $_dl_largest_name $(_dl_human "$_dl_largest_bytes"))"
    elif [ "$DOCKER_LOG_UNREADABLE" -gt 0 ]; then
        _dl_logs_text="unknown (run as root to measure)"
    else
        _dl_logs_text="none"
    fi
    printf "%-${_dl_width}s: %s\n" "Docker container logs" "$_dl_logs_text"

    _dl_unlimited=""
    if [ "$DOCKER_UNLIMITED" -gt 0 ]; then
        _dl_unlimited="; $DOCKER_UNLIMITED of $DOCKER_CONTAINERS container(s) have no size limit"
    fi
    case "$DOCKER_ROTATION_STATE" in
        configured)
            if [ "$DOCKER_UNLIMITED" -gt 0 ]; then
                printf "%-${_dl_width}s: %bconfigured%b%s (recreate them to apply)\n" "Docker log rotation" \
                    "${GREEN:-}" "${NC:-}" "$_dl_unlimited"
            else
                printf "%-${_dl_width}s: %bconfigured%b\n" "Docker log rotation" "${GREEN:-}" "${NC:-}"
            fi
            ;;
        pending-restart)
            printf "%-${_dl_width}s: %bconfigured, restart Docker and recreate containers to apply%b\n" \
                "Docker log rotation" "${YELLOW:-}${BOLD:-}" "${NC:-}"
            ;;
        missing)
            printf "%-${_dl_width}s: %bNOT configured%b (use --docker-log-rotation)%s\n" "Docker log rotation" \
                "${YELLOW:-}${BOLD:-}" "${NC:-}" "$_dl_unlimited"
            ;;
        vm)
            if [ "$DOCKER_UNLIMITED" -gt 0 ]; then
                printf "%-${_dl_width}s: %b%s of %s container(s) have no size limit%b (use --docker-log-rotation for steps)\n" \
                    "Docker log rotation" "${YELLOW:-}${BOLD:-}" "$DOCKER_UNLIMITED" "$DOCKER_CONTAINERS" "${NC:-}"
            else
                printf "%-${_dl_width}s: %ball containers have a size limit%b\n" "Docker log rotation" "${GREEN:-}" "${NC:-}"
            fi
            ;;
        driver)
            printf "%-${_dl_width}s: n/a (%s driver)\n" "Docker log rotation" "$DOCKER_LOGGING_DRIVER"
            ;;
    esac
}
