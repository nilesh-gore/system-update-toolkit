#!/bin/sh
# System Update Utility - ChromeOS (Linux/Crostini)
# A premium script tailored for the ChromeOS Linux environment.

SCRIPT_VERSION="2.6.1"
AUTO_YES=false
DRY_RUN=false
NOTIFY=false

while [ "$#" -gt 0 ]; do
    case "$1" in
        -h|--help)
            echo "Usage: ./chromeos_update_util.sh [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  -h, --help       Show this help message and exit"
            echo "  -v, --version    Show version information"
            echo "  -y, --yes        Automatic yes to all prompts"
            echo "  -d, --dry-run    Show what would be done without making changes"
            echo "  --notify         Send desktop notification on completion"
            echo ""
            echo "A premium system update utility for ChromeOS (Crostini)."
            echo "Automates updates, cache cleanup, and disk recovery."
            exit 0
            ;;
        -v|--version)
            echo "System Update Utility (ChromeOS) v$SCRIPT_VERSION"
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
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
    shift
done

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

send_notification() {
    if [ "$NOTIFY" = true ]; then
        notify-send "📦 System Update Toolkit" "$1" >/dev/null 2>&1 || true
    fi
}

echo "${BOLD}${CYAN}**************************************************${NC}"
echo "${BOLD}${CYAN}*       ChromeOS Linux Update Utility            *${NC}"
echo "${BOLD}${CYAN}**************************************************${NC}"

# Capture disk usage before cleanup
printf "\n${BLUE}==>${NC} ${BOLD}Collecting disk usage before cleanup...${NC}\n"
APT_CACHE_BEFORE=$(du -sb /var/cache/apt/archives 2>/dev/null | awk '{print $1}')
[ -z "$APT_CACHE_BEFORE" ] && APT_CACHE_BEFORE=0

DISK_BEFORE=$(df -B1 "${HOME:-/}" 2>/dev/null | tail -1 | awk '{print $4}')
[ -z "$DISK_BEFORE" ] && DISK_BEFORE=0

# Check for Low Storage Alert (10 GB threshold in bytes)
if [ "$DISK_BEFORE" -gt 0 ] && [ "$DISK_BEFORE" -lt 10737418240 ]; then
    DISK_GB=$(numfmt --to=iec "$DISK_BEFORE" 2>/dev/null || echo "$DISK_BEFORE bytes")
    printf "${RED}⚠️  WARNING: Low Disk Space! Only ${DISK_GB} available on system partition.${NC}\n"
    printf "${YELLOW}Your system may experience severe slowdowns. Running toolkit to recover space is highly recommended!${NC}\n\n"
    send_notification "⚠️ Low Disk Space! Only ${DISK_GB} remaining."
fi

# 1. Update Debian System (Crostini base)
printf "\n${BLUE}==>${NC} ${BOLD}Updating system package definitions...${NC}\n"
if [ "$DRY_RUN" = true ]; then
    echo "${CYAN}[DRY RUN] Would run: sudo apt-get update -y${NC}"
else
    sudo apt-get update -y
fi

echo "${BLUE}==>${NC} ${BOLD}Upgrading installed packages...${NC}"
if [ "$DRY_RUN" = true ]; then
    echo "${CYAN}[DRY RUN] Would run: sudo apt-get full-upgrade -y${NC}"
else
    sudo apt-get full-upgrade -y
fi

# 2. Update Flatpaks (Common on ChromeOS for GUI apps)
if command -v flatpak >/dev/null 2>&1; then
    printf "\n${BLUE}==>${NC} ${BOLD}Updating Flatpak applications...${NC}\n"
    if [ "$DRY_RUN" = true ]; then
        echo "${CYAN}[DRY RUN] Would run: flatpak update -y && flatpak uninstall --unused -y${NC}"
    else
        flatpak update -y
        echo "${BLUE}==>${NC} ${BOLD}Removing unused Flatpak runtimes...${NC}"
        flatpak uninstall --unused -y
    fi
fi

# 3. Clean up APT
printf "\n${BLUE}==>${NC} ${BOLD}Cleaning up system package cache...${NC}\n"
if [ "$DRY_RUN" = true ]; then
    echo "${CYAN}[DRY RUN] Would run: sudo apt-get autoremove -y && sudo apt-get autoclean -y${NC}"
else
    sudo apt-get autoremove -y
    sudo apt-get autoclean -y
fi

# 4. Optional: Update Global NPM Packages
if command -v npm >/dev/null 2>&1; then
    if ask_user "Do you want to check for global NPM package updates?"; then
        echo "Checking global NPM packages..."
        if [ "$DRY_RUN" = true ]; then
            echo "${CYAN}[DRY RUN] Would run: sudo npm update -g${NC}"
        else
            sudo npm update -g || echo "${RED}Some NPM packages failed to update.${NC}"
        fi
    fi
fi

# 5. Optional: Update Global Python Packages (Pip)
if command -v pip3 >/dev/null 2>&1; then
    if ask_user "Do you want to check for global Python (pip3) package updates?"; then
        echo "Updating pip and global packages..."
        if [ "$DRY_RUN" = true ]; then
            echo "${CYAN}[DRY RUN] Would run: python3 -m pip install --upgrade pip && pip3 list --outdated${NC}"
        else
            python3 -m pip install --upgrade pip
            pip3 list --outdated
        fi
    fi
fi

# 6. System consistency check
printf "\n${BLUE}==>${NC} ${BOLD}Checking for system file inconsistencies...${NC}\n"
sudo apt-get check || echo "${YELLOW}Warning: system file inconsistencies detected!${NC}"

# 7. Disk Space Summary
APT_CACHE_AFTER=$(du -sb /var/cache/apt/archives 2>/dev/null | awk '{print $1}')
[ -z "$APT_CACHE_AFTER" ] && APT_CACHE_AFTER=0

DISK_AFTER=$(df -B1 "${HOME:-/}" 2>/dev/null | tail -1 | awk '{print $4}')
[ -z "$DISK_AFTER" ] && DISK_AFTER=0

CLEARED=$((APT_CACHE_BEFORE - APT_CACHE_AFTER))
[ "$CLEARED" -lt 0 ] && CLEARED=0
HUMAN_CLEARED=$(numfmt --to=iec "$CLEARED" 2>/dev/null || echo "$CLEARED bytes")

PART_CLEARED=$((DISK_AFTER - DISK_BEFORE))
[ "$PART_CLEARED" -lt 0 ] && PART_CLEARED=0
HUMAN_PART_SAVED=$(numfmt --to=iec "$PART_CLEARED" 2>/dev/null || echo "$PART_CLEARED bytes")

printf "\n${BOLD}${CYAN}========== CLEANUP SUMMARY ==========${NC}\n"
echo "APT cache cleared     : ${BOLD}$HUMAN_CLEARED${NC}"
echo "Total Partition Saved : ${BOLD}${GREEN}$HUMAN_PART_SAVED${NC}"
echo "System packages       : ${BOLD}Updated & Cleaned${NC}"
if command -v flatpak >/dev/null 2>&1; then
    echo "Flatpak apps          : ${BOLD}Updated & Unused Removed${NC}"
fi
echo "${BOLD}${CYAN}=====================================${NC}"

# 8. Optional terminal history clearing
if ask_user "Do you want to clear terminal history?"; then
    echo "Clearing terminal history..."
    if [ "$DRY_RUN" = true ]; then
        echo "${CYAN}[DRY RUN] Would clear terminal history files${NC}"
    else
        # Try to clear common history files
        for f in "$HOME/.bash_history" "$HOME/.zsh_history"; do
            if [ -f "$f" ]; then
                : >"$f"
                echo "Cleared $f"
            fi
        done
        echo "History cleared."
    fi
else
    echo "Skipping history clear."
fi

printf "\n${GREEN}%s - ChromeOS maintenance completed successfully.${NC}\n" "$(date)"

# Send desktop notification
if [ "$PART_CLEARED" -gt "$CLEARED" ]; then
    send_notification "ChromeOS Maintenance Complete! $HUMAN_PART_SAVED recovered."
else
    send_notification "ChromeOS Maintenance Complete! $HUMAN_CLEARED recovered."
fi
