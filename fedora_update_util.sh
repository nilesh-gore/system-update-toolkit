#!/bin/sh
# System Update Utility - Fedora/RHEL/CentOS
# A premium, robust script to keep your RPM-based Linux environment in top shape.

SCRIPT_VERSION="2.2"
AUTO_YES=false

case "${1:-}" in
    -h|--help)
        echo "Usage: sudo ./fedora_update_util.sh [OPTIONS]"
        echo ""
        echo "Options:"
        echo "  -h, --help       Show this help message and exit"
        echo "  -v, --version    Show version information"
        echo ""
        echo "A premium system update utility for Fedora/RHEL/CentOS."
        echo "Automates updates, cache cleanup, and disk recovery."
        exit 0
        ;;
    -v|--version)
        echo "System Update Utility (Fedora) v$SCRIPT_VERSION"
        exit 0
        ;;
esac

set -eu

# Helper function: prompt user with y/n/a support
ask_user() {
    if [ "$AUTO_YES" = true ]; then
        return 0
    fi
    printf "\n${YELLOW}%s (y/n/a - yes to all): ${NC}" "$1"
    read -r REPLY
    case "$REPLY" in
        a|A) AUTO_YES=true; return 0 ;;
        y|Y) return 0 ;;
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
echo "${BOLD}${CYAN}*        Fedora System Update Utility            *${NC}"
echo "${BOLD}${CYAN}**************************************************${NC}"

# Check for dnf
if ! command -v dnf >/dev/null 2>&1; then
    echo "${RED}Error: dnf package manager not found. This script requires a Fedora/RHEL-based system.${NC}"
    exit 1
fi

printf "\n${BLUE}==>${NC} ${BOLD}Collecting disk usage before cleanup...${NC}\n"

DNF_CACHE_BEFORE=$(du -sb /var/cache/dnf 2>/dev/null | awk '{print $1}')
[ -z "$DNF_CACHE_BEFORE" ] && DNF_CACHE_BEFORE=0

APP_CACHE_BEFORE=$(du -sb /home/*/.cache 2>/dev/null | awk '{sum+=$1} END {print sum}')
[ -z "$APP_CACHE_BEFORE" ] && APP_CACHE_BEFORE=0

JOURNAL_BEFORE=$(journalctl --disk-usage --no-pager 2>/dev/null | grep "disk space" | awk '{print $6}' | numfmt --from=iec 2>/dev/null || echo 0)
[ -z "$JOURNAL_BEFORE" ] && JOURNAL_BEFORE=0

echo "${BLUE}==>${NC} ${BOLD}Refreshing package metadata and upgrading system...${NC}"
sudo dnf upgrade --refresh -y

echo "${BLUE}==>${NC} ${BOLD}Removing unnecessary packages...${NC}"
sudo dnf autoremove -y

echo "${BLUE}==>${NC} ${BOLD}Cleaning up DNF cache...${NC}"
sudo dnf clean all

if ask_user "Do you want to clear user application caches (~/.cache)?"; then
    echo "${BLUE}==>${NC} ${BOLD}Clearing user application cache...${NC}"
    sudo rm -rf /home/*/.cache/* 2>/dev/null || true

    echo "${BLUE}==>${NC} ${BOLD}Clearing thumbnail cache...${NC}"
    sudo rm -rf /home/*/.cache/thumbnails/* 2>/dev/null || true
    sudo rm -rf /home/*/.thumbnails/* 2>/dev/null || true
else
    echo "Skipping user cache cleanup."
fi

echo "${BLUE}==>${NC} ${BOLD}Cleaning systemd journal logs (keeping last 7 days)...${NC}"
sudo journalctl --vacuum-time=7d

if command -v flatpak >/dev/null 2>&1; then
    printf "\n${BLUE}==>${NC} ${BOLD}Updating Flatpak packages...${NC}\n"
    sudo flatpak update -y
    
    echo "${BLUE}==>${NC} ${BOLD}Removing unused Flatpak runtimes...${NC}"
    sudo flatpak uninstall --unused -y
else
    printf "\n${YELLOW}Flatpak is not installed. Skipping.${NC}\n"
fi

if command -v snap >/dev/null 2>&1; then
    printf "\n${BLUE}==>${NC} ${BOLD}Updating Snap packages...${NC}\n"
    sudo snap refresh

    echo "${BLUE}==>${NC} ${BOLD}Removing old Snap revisions...${NC}"
    snap list --all | awk '/disabled/{print $1, $3}' | while read -r snapname revision
    do
        echo "Removing old revision: $snapname (rev $revision)"
        sudo snap remove "$snapname" --revision="$revision" || true
    done
fi

DNF_CACHE_AFTER=$(du -sb /var/cache/dnf 2>/dev/null | awk '{print $1}')
[ -z "$DNF_CACHE_AFTER" ] && DNF_CACHE_AFTER=0

APP_CACHE_AFTER=$(du -sb /home/*/.cache 2>/dev/null | awk '{sum+=$1} END {print sum}')
[ -z "$APP_CACHE_AFTER" ] && APP_CACHE_AFTER=0

JOURNAL_AFTER=$(journalctl --disk-usage --no-pager 2>/dev/null | grep "disk space" | awk '{print $6}' | numfmt --from=iec 2>/dev/null || echo 0)
[ -z "$JOURNAL_AFTER" ] && JOURNAL_AFTER=0

printf "\n${BOLD}${GREEN}========== CLEANUP SUMMARY ==========${NC}\n"

DNF_DIFF=$((DNF_CACHE_BEFORE - DNF_CACHE_AFTER))
APP_DIFF=$((APP_CACHE_BEFORE - APP_CACHE_AFTER))
JOURNAL_DIFF=$((JOURNAL_BEFORE - JOURNAL_AFTER))

[ "$DNF_DIFF" -lt 0 ] && DNF_DIFF=0
[ "$APP_DIFF" -lt 0 ] && APP_DIFF=0
[ "$JOURNAL_DIFF" -lt 0 ] && JOURNAL_DIFF=0

if command -v numfmt >/dev/null 2>&1; then
    echo "DNF cache cleared     : ${BOLD}$(numfmt --to=iec "$DNF_DIFF" 2>/dev/null)${NC}"
    echo "App cache cleared     : ${BOLD}$(numfmt --to=iec "$APP_DIFF" 2>/dev/null)${NC}"
    echo "Journal cleared       : ${BOLD}$(numfmt --to=iec "$JOURNAL_DIFF" 2>/dev/null)${NC}"
    echo "Journal size after    : ${BOLD}$(numfmt --to=iec "$JOURNAL_AFTER" 2>/dev/null)${NC}"
else
    echo "DNF cache cleared     : ${BOLD}$((DNF_DIFF / 1024 / 1024)) MB${NC}"
    echo "App cache cleared     : ${BOLD}$((APP_DIFF / 1024 / 1024)) MB${NC}"
    echo "Journal cleared       : ${BOLD}$((JOURNAL_DIFF / 1024 / 1024)) MB${NC}"
    echo "Journal size after    : ${BOLD}$((JOURNAL_AFTER / 1024 / 1024)) MB${NC}"
fi

echo "${BOLD}${GREEN}=====================================${NC}"

# Optional terminal history clearing
if ask_user "Do you want to clear terminal history?"; then
    echo "Clearing terminal history..."
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
