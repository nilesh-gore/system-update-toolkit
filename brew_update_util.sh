#!/bin/sh
# Brew System Update Utility - macOS
# A premium, interactive script to keep your Homebrew environment in top shape.

SCRIPT_VERSION="2.2"
AUTO_YES=false

case "${1:-}" in
    -h|--help)
        echo "Usage: ./brew_update_util.sh [OPTIONS]"
        echo ""
        echo "Options:"
        echo "  -h, --help       Show this help message and exit"
        echo "  -v, --version    Show version information"
        echo ""
        echo "A premium system update utility for macOS (Homebrew)."
        echo "Automates updates, cache cleanup, and disk recovery."
        exit 0
        ;;
    -v|--version)
        echo "System Update Utility (macOS) v$SCRIPT_VERSION"
        exit 0
        ;;
esac

set -eu

# Helper function: prompt user with y/n/a support
# Usage: ask_user "prompt message" && { do stuff }
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
echo "${BOLD}${CYAN}*        Homebrew System Update Utility          *${NC}"
echo "${BOLD}${CYAN}**************************************************${NC}"

# Check if Homebrew is installed
if ! command -v brew >/dev/null 2>&1; then
    echo "${RED}Error: Homebrew is not installed.${NC} Please install Homebrew first."
    exit 1
fi

# Capture disk usage before cleanup (portable for macOS)
BREW_CACHE_BEFORE=$(du -sk "$(brew --cache)" 2>/dev/null | awk '{print $1}')
BREW_CACHE_BEFORE=${BREW_CACHE_BEFORE:-0}

# 1. Update Homebrew
printf "\n${BLUE}==>${NC} ${BOLD}Updating Homebrew definitions...${NC}\n"
brew update

# 2. Check for outdated packages
OUTDATED_FORMULAE=$(brew outdated --formula | wc -l | xargs)
OUTDATED_CASKS=$(brew outdated --cask | wc -l | xargs)

echo "${GREEN}Found $OUTDATED_FORMULAE outdated formulae and $OUTDATED_CASKS outdated casks.${NC}"

# 3. Upgrade installed formulae
if [ "$OUTDATED_FORMULAE" -gt 0 ]; then
    printf "\n${BLUE}==>${NC} ${BOLD}Upgrading installed formulae...${NC}\n"
    brew upgrade
else
    printf "\n${GREEN}All formulae are already up to date.${NC}\n"
fi

# 4. Upgrade installed casks
if [ "$OUTDATED_CASKS" -gt 0 ]; then
    printf "\n${BLUE}==>${NC} ${BOLD}Upgrading installed casks...${NC}\n"
    echo "${YELLOW}Tip: Greedy mode also upgrades casks that auto-update (Chrome, Slack, etc.).${NC}"
    if ask_user "Do you want to use greedy upgrade for casks?"; then
        brew upgrade --cask --greedy
    else
        brew upgrade --cask
    fi
else
    printf "\n${GREEN}All casks are already up to date.${NC}\n"
fi

# 5. Remove unused dependencies
printf "\n${BLUE}==>${NC} ${BOLD}Removing unused dependencies (autoremove)...${NC}\n"
brew autoremove

# 6. Cleanup old versions and downloads
printf "\n${BLUE}==>${NC} ${BOLD}Cleaning up Homebrew...${NC}\n"
brew cleanup -s

# 7. Optional: Remove old cached downloads
if ask_user "Do you want to remove old cached downloads from ~/Library/Caches/Homebrew?"; then
    echo "Removing old cached downloads..."
    rm -rf "$HOME/Library/Caches/Homebrew/"* 2>/dev/null
else
    echo "Skipping removal of Homebrew cache."
fi

# 8. Check for any services that might need a restart
if command -v brew services >/dev/null 2>&1; then
    printf "\n${BLUE}==>${NC} ${BOLD}Checking Homebrew services...${NC}\n"
    # Check if any services are started
    if brew services list | grep -q "started"; then
        echo "${YELLOW}Note: Some services are running. If they were updated, you might need to restart them.${NC}"
        if ask_user "Would you like to see the list of running services?"; then
            brew services list
        fi
    fi
fi

# 9. Optional: Run Brew Doctor
if ask_user "Do you want to run 'brew doctor' to check for potential issues?"; then
    echo "Running brew doctor..."
    brew doctor || echo "${YELLOW}Brew doctor found some issues (see above).${NC}"
fi

# Capture disk usage after cleanup
BREW_CACHE_AFTER=$(du -sk "$(brew --cache)" 2>/dev/null | awk '{print $1}')
BREW_CACHE_AFTER=${BREW_CACHE_AFTER:-0}

# Human readable function (macOS compatible)
human_readable() {
    awk -v sum="$1" 'function human(x) {
        s="KB MB GB TB PB"
        split(s,arr)
        for (i=1; x>=1024 && i<5; i++) x/=1024
        return sprintf("%.2f %s", x, arr[i])
    }
    BEGIN { print human(sum) }'
}

# Display summary
CLEARED=$((BREW_CACHE_BEFORE - BREW_CACHE_AFTER))
if [ "$CLEARED" -lt 0 ]; then CLEARED=0; fi

printf "\n${BOLD}${GREEN}========== CLEANUP SUMMARY ==========${NC}\n"
echo "Homebrew cache cleared: ${BOLD}$(human_readable "$CLEARED")${NC}"
echo "${BOLD}${GREEN}=====================================${NC}"

# Optional terminal history clearing
if ask_user "Do you want to clear terminal history?"; then
    echo "Clearing terminal history..."
    if [ -n "${HISTFILE:-}" ] && [ -f "$HISTFILE" ]; then
        : >"$HISTFILE"
        echo "History file cleared."
    else
        # Try default bash/zsh paths if HISTFILE is not set
        if [ -f "$HOME/.zsh_history" ]; then
            : >"$HOME/.zsh_history"
            echo "Zsh history cleared."
        elif [ -f "$HOME/.bash_history" ]; then
            : >"$HOME/.bash_history"
            echo "Bash history cleared."
        else
            echo "No history file found."
        fi
    fi
else
    echo "Skipping terminal history clear."
fi

printf "\n${CYAN}%s - Homebrew system update completed successfully.${NC}\n" "$(date)"
