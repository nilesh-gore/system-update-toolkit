#!/bin/sh
# System Update Utility - ChromeOS (Linux/Crostini)
# A premium script tailored for the ChromeOS Linux environment.

SCRIPT_VERSION="2.1"
AUTO_YES=false

case "${1:-}" in
    -h|--help)
        echo "Usage: ./chromeos_update_util.sh [OPTIONS]"
        echo ""
        echo "Options:"
        echo "  -h, --help       Show this help message and exit"
        echo "  -v, --version    Show version information"
        echo "  -y, --yes        Answer yes to all prompts (non-interactive mode)"
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
esac

set -eu

# Helper function: prompt user with y/n/a support
# Usage: ask_user "prompt message" && { do stuff }
ask_user() {
    if [ "$AUTO_YES" = true ]; then
        return 0
    fi
    echo "\n${YELLOW}$1 (y/n/a - yes to all): ${NC}"
    read REPLY
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
echo "${BOLD}${CYAN}*       ChromeOS Linux Update Utility            *${NC}"
echo "${BOLD}${CYAN}**************************************************${NC}"

# Capture disk usage before cleanup
echo "\n${BLUE}==>${NC} ${BOLD}Collecting disk usage before cleanup...${NC}"
APT_CACHE_BEFORE=$(du -sk /var/cache/apt/archives 2>/dev/null | awk '{print $1}')
APT_CACHE_BEFORE=${APT_CACHE_BEFORE:-0}

# 1. Update Debian System (Crostini base)
echo "\n${BLUE}==>${NC} ${BOLD}Updating system package definitions...${NC}"
sudo apt-get update -y

echo "${BLUE}==>${NC} ${BOLD}Upgrading installed packages...${NC}"
sudo apt-get full-upgrade -y

# 2. Update Flatpaks (Common on ChromeOS for GUI apps)
if command -v flatpak >/dev/null 2>&1; then
    echo "\n${BLUE}==>${NC} ${BOLD}Updating Flatpak applications...${NC}"
    flatpak update -y
    echo "${BLUE}==>${NC} ${BOLD}Removing unused Flatpak runtimes...${NC}"
    flatpak uninstall --unused -y
else
    echo "\n${YELLOW}Flatpak not installed. Skipping Flatpak updates.${NC}"
fi

# 3. Clean up APT
echo "\n${BLUE}==>${NC} ${BOLD}Cleaning up system package cache...${NC}"
sudo apt-get autoremove -y
sudo apt-get autoclean -y

# 4. Optional: Update Global NPM Packages
if command -v npm >/dev/null 2>&1; then
    if ask_user "Do you want to check for global NPM package updates?"; then
        echo "Checking global NPM packages..."
        sudo npm update -g || echo "${RED}Some NPM packages failed to update.${NC}"
    fi
fi

# 5. Optional: Update Global Python Packages (Pip)
if command -v pip3 >/dev/null 2>&1; then
    if ask_user "Do you want to check for global Python (pip3) package updates?"; then
        echo "Updating pip and global packages..."
        python3 -m pip install --upgrade pip
        # Note: Upgrading all global pips can be risky, so we just do pip itself by default
        # but we can list outdated ones
        pip3 list --outdated
    fi
fi

# 6. System consistency check
echo "\n${BLUE}==>${NC} ${BOLD}Checking for system file inconsistencies...${NC}"
sudo apt-get check

# 7. Disk Space Summary
APT_CACHE_AFTER=$(du -sk /var/cache/apt/archives 2>/dev/null | awk '{print $1}')
APT_CACHE_AFTER=${APT_CACHE_AFTER:-0}

CLEARED=$((APT_CACHE_BEFORE - APT_CACHE_AFTER))
if [ "$CLEARED" -lt 0 ]; then CLEARED=0; fi

echo "\n${BOLD}${GREEN}========== CLEANUP SUMMARY ==========${NC}"
echo "APT cache cleared : ${BOLD}${CLEARED} KB${NC}"
echo "System packages   : ${BOLD}Updated & Cleaned${NC}"
if command -v flatpak >/dev/null 2>&1; then
    echo "Flatpak apps      : ${BOLD}Updated${NC}"
fi
echo "${BOLD}${GREEN}=====================================${NC}"

# 8. Optional terminal history clearing
if ask_user "Do you want to clear terminal history?"; then
    echo "Clearing terminal history..."
    [ -f "$HOME/.bash_history" ] && >"$HOME/.bash_history"
    [ -f "$HOME/.zsh_history" ] && >"$HOME/.zsh_history"
    echo "History cleared."
else
    echo "Skipping history clear."
fi

echo "\n${CYAN}$(date) - ChromeOS Linux update completed successfully.${NC}"
