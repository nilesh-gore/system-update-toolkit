#!/bin/sh
# System Update Utility - Ubuntu/Debian
# A premium, robust script to keep your Linux environment in top shape.

SCRIPT_VERSION="2.3"
AUTO_YES=false

case "${1:-}" in
    -h|--help)
        echo "Usage: sudo ./update_util.sh [OPTIONS]"
        echo ""
        echo "Options:"
        echo "  -h, --help       Show this help message and exit"
        echo "  -v, --version    Show version information"
        echo "  -y, --yes        Automatic yes to all prompts"
        echo ""
        echo "A premium system update utility for Ubuntu/Debian."
        echo "Automates updates, cache cleanup, and disk recovery."
        exit 0
        ;;
    -v|--version)
        echo "System Update Utility (Linux) v$SCRIPT_VERSION"
        exit 0
        ;;
    -y|--yes)
        AUTO_YES=true
        shift
        ;;
esac

set -eu

# Helper function: prompt user with y/n/a support
# Usage: ask_user "prompt message" && { do stuff }
ask_user() {
    if [ "$AUTO_YES" = true ]; then
        return 0
    fi
    printf "\n${YELLOW}%s${NC}\n" "$1"
    printf "${BOLD}[y]es / [n]o / [a]ll${NC}: "
    read -r REPLY
    case "$REPLY" in
        a|A|all|ALL) AUTO_YES=true; return 0 ;;
        y|Y|yes|YES) return 0 ;;
        *) return 1 ;;
    esac
}

# Color definitions for a premium look
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
NC='\033[0m' # No Color

echo "${BOLD}${CYAN}**************************************************${NC}"
echo "${BOLD}${CYAN}*        Linux System Update Utility             *${NC}"
echo "${BOLD}${CYAN}**************************************************${NC}"

DEBIAN_FRONTEND=noninteractive
export DEBIAN_FRONTEND

printf "\n${BLUE}==>${NC} ${BOLD}Collecting disk usage before cleanup...${NC}\n"

APT_CACHE_BEFORE=$(du -sb /var/cache/apt/archives 2>/dev/null | awk '{print $1}')
[ -z "$APT_CACHE_BEFORE" ] && APT_CACHE_BEFORE=0

APP_CACHE_BEFORE=$(du -sb /home/*/.cache 2>/dev/null | awk '{sum+=$1} END {print sum}')
[ -z "$APP_CACHE_BEFORE" ] && APP_CACHE_BEFORE=0

JOURNAL_BEFORE=$(journalctl --disk-usage --no-pager 2>/dev/null | \
    grep "disk space" | awk '{print $6}' | numfmt --from=iec 2>/dev/null)
[ -z "$JOURNAL_BEFORE" ] && JOURNAL_BEFORE=0

echo "${BLUE}==>${NC} ${BOLD}Updating package list...${NC}"
sudo apt-get update -y

echo "${BLUE}==>${NC} ${BOLD}Upgrading installed packages...${NC}"
sudo apt-get full-upgrade -y

echo "${BLUE}==>${NC} ${BOLD}Installing missing dependencies (if any)...${NC}"
sudo apt-get install -f -y

echo "${BLUE}==>${NC} ${BOLD}Reconfiguring any broken packages...${NC}"
sudo dpkg --configure -a

echo "${BLUE}==>${NC} ${BOLD}Removing unnecessary packages...${NC}"
sudo apt-get autoremove --purge -y

echo "${BLUE}==>${NC} ${BOLD}Cleaning up retrieved package files...${NC}"
sudo apt-get autoclean -y
sudo apt-get clean -y

if ask_user "Do you want to clear user application caches (~/.cache)?"; then
    echo "${BLUE}==>${NC} ${BOLD}Clearing user application cache...${NC}"
    sudo rm -rf /home/*/.cache/* 2>/dev/null

    echo "${BLUE}==>${NC} ${BOLD}Clearing thumbnail cache...${NC}"
    sudo rm -rf /home/*/.cache/thumbnails/* 2>/dev/null
    sudo rm -rf /home/*/.thumbnails/* 2>/dev/null
else
    echo "Skipping user cache cleanup."
fi

echo "${BLUE}==>${NC} ${BOLD}Cleaning systemd journal logs (keeping last 7 days)...${NC}"
sudo journalctl --vacuum-time=7d

echo "${BLUE}==>${NC} ${BOLD}Listing held packages...${NC}"
sudo apt-mark showhold

echo "${BLUE}==>${NC} ${BOLD}Verifying package installation integrity...${NC}"
if command -v debsums >/dev/null 2>&1; then
    sudo debsums -s || echo "${RED}Integrity check found issues!${NC}"
else
    echo "${YELLOW}debsums not installed, skipping integrity check.${NC}"
fi

if command -v snap >/dev/null 2>&1; then
    printf "\n${BLUE}==>${NC} ${BOLD}Updating Snap packages...${NC}\n"
    sudo snap refresh

    echo "${BLUE}==>${NC} ${BOLD}Removing old Snap revisions...${NC}"
    snap list --all | awk '/disabled/{print $1, $3}' | while read -r snapname revision
    do
        echo "Removing old revision: $snapname (rev $revision)"
        sudo snap remove "$snapname" --revision="$revision"
    done
else
    printf "\n${YELLOW}Snap is not installed.${NC}\n"
fi

printf "\n${BLUE}==>${NC} ${BOLD}Checking for system file inconsistencies...${NC}\n"
sudo apt-get check

APT_CACHE_AFTER=$(du -sb /var/cache/apt/archives 2>/dev/null | awk '{print $1}')
[ -z "$APT_CACHE_AFTER" ] && APT_CACHE_AFTER=0

APP_CACHE_AFTER=$(du -sb /home/*/.cache 2>/dev/null | awk '{sum+=$1} END {print sum}')
[ -z "$APP_CACHE_AFTER" ] && APP_CACHE_AFTER=0

JOURNAL_AFTER=$(journalctl --disk-usage --no-pager 2>/dev/null | \
    grep "disk space" | awk '{print $6}' | numfmt --from=iec 2>/dev/null)
[ -z "$JOURNAL_AFTER" ] && JOURNAL_AFTER=0

printf "\n${BOLD}${GREEN}========== CLEANUP SUMMARY ==========${NC}\n"

APT_DIFF=$((APT_CACHE_BEFORE - APT_CACHE_AFTER))
APP_DIFF=$((APP_CACHE_BEFORE - APP_CACHE_AFTER))
JOURNAL_DIFF=$((JOURNAL_BEFORE - JOURNAL_AFTER))

[ "$APT_DIFF" -lt 0 ] && APT_DIFF=0
[ "$APP_DIFF" -lt 0 ] && APP_DIFF=0
[ "$JOURNAL_DIFF" -lt 0 ] && JOURNAL_DIFF=0

echo "APT cache cleared     : ${BOLD}$(numfmt --to=iec "$APT_DIFF" 2>/dev/null)${NC}"
echo "App cache cleared     : ${BOLD}$(numfmt --to=iec "$APP_DIFF" 2>/dev/null)${NC}"
echo "Journal cleared       : ${BOLD}$(numfmt --to=iec "$JOURNAL_DIFF" 2>/dev/null)${NC}"
echo "Journal size after    : ${BOLD}$(numfmt --to=iec "$JOURNAL_AFTER" 2>/dev/null)${NC}"

echo "${BOLD}${GREEN}=====================================${NC}"

# Optional terminal history clearing
if ask_user "Do you want to clear terminal history?"; then
    echo "Clearing terminal history..."
    # Try to clear common history files
    for f in "$HOME/.bash_history" "$HOME/.zsh_history"; do
        if [ -f "$f" ]; then
            : >"$f"
            echo "Cleared $f"
        fi
    done
else
    echo "Skipping terminal history clear."
fi

printf "\n${CYAN}%s - System update completed successfully.${NC}\n" "$(date)" | sudo tee -a /var/log/sysupdate.log