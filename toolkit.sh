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

SCRIPT_VERSION="2.5"
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
    
    if [ -f "$SCRIPT_DIR/$_script_name" ]; then
        printf "${GREEN}✅ Detected OS: ${BOLD}%s${NC}\n" "$_os_display"
        printf "${CYAN}🚀 Launching specialized utility: %s...${NC}\n\n" "$_script_name"
        chmod +x "$SCRIPT_DIR/$_script_name"
        # Execute with all passed arguments
        # shellcheck disable=SC2086
        sh "$SCRIPT_DIR/$_script_name" "$@"
    else
        printf "${RED}❌ Error: Sub-script '%s' not found in %s${NC}\n" "$_script_name" "$SCRIPT_DIR"
        exit 1
    fi
}

# Main Execution
OS=$(detect_os)

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
        echo "  -y, --yes        Automatic yes to all prompts (non-interactive)"
        echo "  -d, --dry-run    Show what would be done without making changes"
        echo "  --notify         Send desktop notification on completion"
        echo "  --schedule       Setup weekly automated maintenance (Unix only)"
        exit 0
        ;;
    -v|--version)
        echo "System Update Toolkit v$SCRIPT_VERSION (Unified Wrapper)"
        exit 0
        ;;
    --schedule)
        OS=$(detect_os)
        if [ "$OS" = "windows" ] || [ "$OS" = "unknown" ]; then
            echo "${RED}❌ Error: Automated scheduling is currently only supported on Unix-based systems (Linux/macOS).${NC}"
            echo "For Windows, please use 'Task Scheduler' to run toolkit.ps1 weekly."
            exit 1
        fi
        printf "${YELLOW}Setting up weekly maintenance (Mondays at Midnight)...${NC}\n"
        # Create secure temporary files
        cron_bkp=$(mktemp)
        cron_new=$(mktemp)
        # Check if crontab exists, if not create empty one
        crontab -l > "$cron_bkp" 2>/dev/null || touch "$cron_bkp"
        # Remove existing toolkit entries to avoid duplicates
        grep -v "toolkit.sh" "$cron_bkp" > "$cron_new"
        # Add new entry
        echo "0 0 * * 1 \"$SCRIPT_DIR/toolkit.sh\" -y --notify > /dev/null 2>&1" >> "$cron_new"
        crontab "$cron_new"
        rm -f "$cron_bkp" "$cron_new"
        echo "${GREEN}✅ Successfully scheduled weekly maintenance!${NC}"
        exit 0
        ;;
esac

print_banner

case "$OS" in
    macos)
        run_script "brew_update_util.sh" "macOS (Homebrew)" "$@"
        ;;
    debian)
        run_script "update_util.sh" "Ubuntu/Debian (APT)" "$@"
        ;;
    fedora)
        run_script "fedora_update_util.sh" "Fedora/RHEL (DNF)" "$@"
        ;;
    chromeos)
        run_script "chromeos_update_util.sh" "ChromeOS (Linux)" "$@"
        ;;
    windows)
        printf "${GREEN}✅ Detected OS: ${BOLD}Windows${NC}\n"
        if command -v powershell.exe >/dev/null 2>&1 || command -v powershell >/dev/null 2>&1; then
            printf "${CYAN}🚀 Launching PowerShell utility...${NC}\n\n"
            if command -v powershell.exe >/dev/null 2>&1; then
                powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$SCRIPT_DIR/win_update_util.ps1" "$@"
            else
                powershell -NoProfile -ExecutionPolicy Bypass -File "$SCRIPT_DIR/win_update_util.ps1" "$@"
            fi
        else
            echo "${YELLOW}⚠️  PowerShell not found. Please run the PowerShell script manually:${NC}"
            echo "   powershell -File \".\win_update_util.ps1\""
        fi
        exit 0
        ;;
    linux_generic)
        echo "${YELLOW}⚠️  Detected generic Linux. Attempting to use Debian/Ubuntu script...${NC}"
        run_script "update_util.sh" "Linux (Generic)" "$@"
        ;;
    *)
        echo "${RED}❌ Error: Unsupported Operating System detected.${NC}"
        echo "Please visit https://github.com/nilesh-gore/system-update-toolkit for manual instructions."
        exit 1
        ;;
esac
