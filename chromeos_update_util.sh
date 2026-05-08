#!/bin/sh
# System Update Utility - ChromeOS (Linux/Crostini)
# A premium script tailored for the ChromeOS Linux environment.

SCRIPT_VERSION="2.1"

case "${1:-}" in
    -h|--help)
        echo "Usage: ./chromeos_update_util.sh [OPTIONS]"
        echo ""
        echo "Options:"
        echo "  -h, --help       Show this help message and exit"
        echo "  -v, --version    Show version information"
        echo ""
        echo "A premium system update utility for ChromeOS (Crostini)."
        echo "Automates updates, cache cleanup, and disk recovery."
        exit 0
        ;;
    -v|--version)
        echo "System Update Utility (ChromeOS) v$SCRIPT_VERSION"
        exit 0
        ;;
esac

set -eu

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
    echo "\n${YELLOW}Do you want to check for global NPM package updates? (y/n): ${NC}"
    read UPDATE_NPM
    case "$UPDATE_NPM" in
        y|Y)
            echo "Checking global NPM packages..."
            sudo npm update -g || echo "${RED}Some NPM packages failed to update.${NC}"
            ;;
    esac
fi

# 5. Optional: Update Global Python Packages (Pip)
if command -v pip3 >/dev/null 2>&1; then
    echo "\n${YELLOW}Do you want to check for global Python (pip3) package updates? (y/n): ${NC}"
    read UPDATE_PIP
    case "$UPDATE_PIP" in
        y|Y)
            echo "Updating pip and global packages..."
            python3 -m pip install --upgrade pip
            # Note: Upgrading all global pips can be risky, so we just do pip itself by default
            # but we can list outdated ones
            pip3 list --outdated
            ;;
    esac
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

# 7. Optional terminal history clearing
echo "\n${YELLOW}Do you want to clear terminal history? (y/n): ${NC}"
read CLEAR_HISTORY
case "$CLEAR_HISTORY" in
    y|Y)
        echo "Clearing terminal history..."
        [ -f "$HOME/.bash_history" ] && > "$HOME/.bash_history"
        [ -f "$HOME/.zsh_history" ] && > "$HOME/.zsh_history"
        echo "History cleared."
        ;;
    *)
        echo "Skipping history clear."
        ;;
esac

echo "\n${CYAN}$(date) - ChromeOS Linux update completed successfully.${NC}"
