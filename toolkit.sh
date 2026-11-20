#!/bin/sh
# ==============================================================================
# System Update Toolkit — Unified Wrapper
# ==============================================================================
# This script automatically detects your Operating System and executes the
# appropriate specialized update utility.
#
# Website: https://github.com/nilesh-gore/system-update-toolkit
# License: MIT
# ==============================================================================

SCRIPT_VERSION="3.2.0"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

set -eu

# Color definitions
CYAN='\033[0;36m'
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
NC='\033[0m'

print_banner() {
    echo "${BOLD}${CYAN}**************************************************${NC}"
    echo "${BOLD}${CYAN}*        System Update Toolkit — Wrapper         *${NC}"
    echo "${BOLD}${CYAN}**************************************************${NC}"
}

detect_os() {
    case "$(uname -s)" in
        Linux*)
            if [ -f /etc/os-release ]; then
                . /etc/os-release
                # Check for ChromeOS first (special case of Debian container)
                if [ -d /opt/google/cros-containers ] || grep -qi "chromeos" /proc/version 2>/dev/null; then
                    echo "chromeos"
                elif echo "$ID" | grep -qiE "debian|ubuntu|linuxmint|pop"; then
                    echo "debian"
                elif echo "$ID" | grep -qiE "fedora|centos|rhel|almalinux|rocky"; then
                    echo "fedora"
                elif echo "$ID" | grep -qiE "arch|manjaro|endeavouros|garuda|arcolinux"; then
                    echo "arch"
                elif echo "$ID" | grep -qiE "opensuse|sles|suse"; then
                    echo "opensuse"
                else
                    echo "linux_generic"
                fi
            else
                echo "linux_generic"
            fi
            ;;
        Darwin*)
            echo "macos"
            ;;
        CYGWIN*|MINGW*|MSYS*)
            echo "windows"
            ;;
        *)
            echo "unknown"
            ;;
    esac
}

run_script() {
    _script_name="$1"
    _os_display="$2"
    shift 2
    
    if [ -f "$SCRIPT_DIR/$_script_name" ]; then
        printf "${GREEN}✅ Detected OS: ${BOLD}%s${NC}\n" "$_os_display"
        printf "${CYAN}🚀 Launching specialized utility: %s...${NC}\n\n" "$_script_name"
        chmod +x "$SCRIPT_DIR/$_script_name"
        # Execute with all passed arguments, respecting shebang header interpreters
        "$SCRIPT_DIR/$_script_name" "$@"
    else
        printf "${RED}❌ Error: Sub-script '%s' not found in %s${NC}\n" "$_script_name" "$SCRIPT_DIR"
        exit 1
    fi
}

# Weekly maintenance via cron.
# Linux: the job goes in root's crontab. debian_update_util.sh requires root,
# and the other Linux scripts call sudo, which cannot prompt for a password
# under cron. macOS: the job stays in the user's crontab, because Homebrew
# refuses to run as root. Every entry carries SCHEDULE_MARKER so updating or
# removing it never touches other cron lines.
SCHEDULE_MARKER="# system-update-toolkit"
# Exact tail of the entry written by toolkit.sh versions before 3.2.0.
LEGACY_SCHEDULE_TAIL='toolkit.sh" -y --notify > /dev/null 2>&1'

schedule_crontab() {
    if [ "$CRON_AS_ROOT" = true ] && [ "$(id -u)" -ne 0 ]; then
        sudo crontab "$@"
    else
        crontab "$@"
    fi
}

# Remove toolkit entries using the crontab command given as arguments.
remove_schedule_entries() {
    cron_old=$(mktemp)
    cron_new=$(mktemp)
    "$@" -l >"$cron_old" 2>/dev/null || : >"$cron_old"
    grep -v -F -e "$SCHEDULE_MARKER" -e "$LEGACY_SCHEDULE_TAIL" "$cron_old" >"$cron_new" || true
    if ! cmp -s "$cron_old" "$cron_new"; then
        "$@" "$cron_new"
    fi
    rm -f "$cron_old" "$cron_new"
}

manage_schedule() {
    OS=$(detect_os)
    if [ "$OS" = "windows" ] || [ "$OS" = "unknown" ]; then
        printf "${RED}❌ Error: Automated scheduling is currently only supported on Unix-based systems (Linux/macOS).${NC}\n"
        echo "For Windows, use Task Scheduler to run win_update_util.ps1 -Yes weekly (see README)."
        exit 1
    fi

    if [ "$OS" = "macos" ]; then
        CRON_AS_ROOT=false
        cron_path="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
        cron_log="$HOME/Library/Logs/system-update-toolkit.log"
    else
        CRON_AS_ROOT=true
        cron_path="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
        cron_log="/var/log/sysupdate-cron.log"
        # Older versions wrote the job to the invoking user's crontab, where it
        # could not run; remove it from there too.
        if [ "$(id -u)" -ne 0 ]; then
            remove_schedule_entries crontab
        fi
    fi

    remove_schedule_entries schedule_crontab

    if [ "$1" = "--unschedule" ]; then
        printf "${GREEN}✅ Weekly maintenance schedule removed.${NC}\n"
        return 0
    fi

    printf "${YELLOW}Setting up weekly maintenance (Mondays at midnight)...${NC}\n"
    cron_new=$(mktemp)
    schedule_crontab -l >"$cron_new" 2>/dev/null || : >"$cron_new"
    printf '0 0 * * 1 PATH=%s "%s/toolkit.sh" -y --notify >>"%s" 2>&1 %s\n' \
        "$cron_path" "$SCRIPT_DIR" "$cron_log" "$SCHEDULE_MARKER" >>"$cron_new"
    schedule_crontab "$cron_new"
    rm -f "$cron_new"

    if [ "$CRON_AS_ROOT" = true ]; then
        printf "${GREEN}✅ Scheduled weekly maintenance in root's crontab.${NC}\n"
    else
        printf "${GREEN}✅ Scheduled weekly maintenance in your crontab.${NC}\n"
    fi
    echo "   Log file: $cron_log"
    echo "   The job runs with -y: destructive steps (cache, history, Docker cleanup) are skipped."
    echo "   Remove it with: ./toolkit.sh --unschedule"
}

# Main Execution

# Handle help/version before banner if needed, or just let sub-scripts handle it
case "${1:-}" in
    -h|--help)
        print_banner
        echo "Usage: ./toolkit.sh [OPTIONS]"
        echo ""
        echo "The unified entry point for the System Update Toolkit."
        echo "It automatically detects your OS and runs the correct maintenance script."
        echo ""
        echo "Options:"
        echo "  -h, --help       Show this help and exit"
        echo "  -v, --version    Show version information"
        echo "  -y, --yes        Automatic yes to routine prompts (never to destructive ones)"
        echo "  -d, --dry-run    Show what would be done without making changes"
        echo "  --notify         Send desktop notification on completion"
        echo "  --schedule       Setup weekly automated maintenance (Unix only)"
        echo "  --unschedule     Remove the weekly maintenance job"
        echo ""
        echo "Destructive actions (never enabled by --yes):"
        echo "  --clear-cache    Clear user application caches (Linux)"
        echo "  --clear-history  Clear shell history files"
        echo "  --docker-cleanup Run 'docker system prune --volumes' (deletes unused volumes)"
        echo ""
        echo "Docker log options (Unix scripts; passed through to the platform script):"
        echo "  --docker-logs-truncate[=SIZE]  Empty container logs larger than SIZE (default 100M)"
        echo "  --docker-log-rotation          Configure Docker log rotation (max-size 50m, max-file 3)"
        exit 0
        ;;
    -v|--version)
        echo "System Update Toolkit v$SCRIPT_VERSION (Unified Wrapper)"
        exit 0
        ;;
    --schedule|--unschedule)
        manage_schedule "$1"
        exit 0
        ;;
esac

OS=$(detect_os)
print_banner

case "$OS" in
    macos)
        run_script "brew_update_util.sh" "macOS (Homebrew)" "$@"
        ;;
    debian)
        run_script "debian_update_util.sh" "Ubuntu/Debian (APT)" "$@"
        ;;
    fedora)
        run_script "fedora_update_util.sh" "Fedora/RHEL (DNF)" "$@"
        ;;
    arch)
        run_script "arch_update_util.sh" "Arch Linux (Pacman)" "$@"
        ;;
    opensuse)
        run_script "opensuse_update_util.sh" "openSUSE (Zypper)" "$@"
        ;;
    chromeos)
        run_script "chromeos_update_util.sh" "ChromeOS (Linux)" "$@"
        ;;
    windows)
        printf "${GREEN}✅ Detected OS: ${BOLD}Windows${NC}\n"
        if command -v powershell.exe >/dev/null 2>&1 || command -v powershell >/dev/null 2>&1; then
            # The PowerShell script uses -Yes/-DryRun style switches, so translate
            # the Unix-style options instead of passing them through unchanged.
            ps_args=""
            for arg in "$@"; do
                case "$arg" in
                    -y|--yes) ps_args="$ps_args -Yes" ;;
                    -d|--dry-run) ps_args="$ps_args -DryRun" ;;
                    --notify) ps_args="$ps_args -Notify" ;;
                    --clear-history) ps_args="$ps_args -ClearHistory" ;;
                    --docker-cleanup) ps_args="$ps_args -DockerCleanup" ;;
                    *) printf "${YELLOW}Ignoring option not supported on Windows: %s${NC}\n" "$arg" ;;
                esac
            done
            printf "${CYAN}🚀 Launching PowerShell utility...${NC}\n\n"
            ps_exe=powershell
            if command -v powershell.exe >/dev/null 2>&1; then
                ps_exe=powershell.exe
            fi
            # shellcheck disable=SC2086 # ps_args only ever holds the fixed switch names above
            "$ps_exe" -NoProfile -ExecutionPolicy Bypass -File "$SCRIPT_DIR/win_update_util.ps1" $ps_args
        else
            echo "${YELLOW}⚠️  PowerShell not found. Please run the PowerShell script manually:${NC}"
            echo "   powershell -File \".\win_update_util.ps1\""
        fi
        exit 0
        ;;
    linux_generic)
        echo "${YELLOW}⚠️  Detected generic Linux. Attempting to use Debian/Ubuntu script...${NC}"
        run_script "debian_update_util.sh" "Linux (Generic)" "$@"
        ;;
    *)
        echo "${RED}❌ Error: Unsupported Operating System detected.${NC}"
        echo "Please visit https://github.com/nilesh-gore/system-update-toolkit for manual instructions."
        exit 1
        ;;
esac
