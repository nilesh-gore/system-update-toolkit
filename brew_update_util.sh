#!/bin/sh
# Brew System Update Utility - macOS
# A premium, interactive script to keep your Homebrew environment in top shape.

SCRIPT_VERSION="2.5"
AUTO_YES=false
DRY_RUN=false
NOTIFY=false

while [ "$#" -gt 0 ]; do
    case "$1" in
        -h|--help)
            echo "Usage: ./brew_update_util.sh [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  -h, --help       Show this help message and exit"
            echo "  -v, --version    Show version information"
            echo "  -y, --yes        Automatic yes to all prompts"
            echo "  -d, --dry-run    Show what would be done without making changes"
            echo "  --notify         Send desktop notification on completion"
            echo ""
            echo "A premium system update utility for macOS (Homebrew)."
            echo "Automates updates, cache cleanup, and disk recovery."
            exit 0
            ;;
        -v|--version)
            echo "System Update Utility (macOS) v$SCRIPT_VERSION"
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
        osascript -e "display notification \"$1\" with title \"📦 System Update Toolkit\"" >/dev/null 2>&1 || true
    fi
}

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

# Capture partition available space before cleanup (in KB)
DISK_BEFORE=$(df -k "${HOME:-/}" 2>/dev/null | tail -1 | awk '{print $4}')
DISK_BEFORE=${DISK_BEFORE:-0}

# 1. Update Homebrew
printf "\n${BLUE}==>${NC} ${BOLD}Updating Homebrew definitions...${NC}\n"
if [ "$DRY_RUN" = true ]; then
    echo "${CYAN}[DRY RUN] Would run: brew update${NC}"
else
    brew update
fi

# 2. Check for outdated packages
OUTDATED_FORMULAE=$(brew outdated --formula | wc -l | xargs)
OUTDATED_CASKS=$(brew outdated --cask | wc -l | xargs)

echo "${GREEN}Found $OUTDATED_FORMULAE outdated formulae and $OUTDATED_CASKS outdated casks.${NC}"

# 3. Upgrade installed formulae
if [ "$OUTDATED_FORMULAE" -gt 0 ]; then
    printf "\n${BLUE}==>${NC} ${BOLD}Upgrading installed formulae...${NC}\n"
    if [ "$DRY_RUN" = true ]; then
        echo "${CYAN}[DRY RUN] Would run: brew upgrade${NC}"
    else
        brew upgrade
    fi
else
    printf "\n${GREEN}All formulae are already up to date.${NC}\n"
fi

# 4. Upgrade installed casks
if [ "$OUTDATED_CASKS" -gt 0 ]; then
    printf "\n${BLUE}==>${NC} ${BOLD}Upgrading installed casks...${NC}\n"
    echo "${YELLOW}Tip: Greedy mode also upgrades casks that auto-update (Chrome, Slack, etc.).${NC}"
    if ask_user "Do you want to use greedy upgrade for casks?"; then
        if [ "$DRY_RUN" = true ]; then
            echo "${CYAN}[DRY RUN] Would run: brew upgrade --cask --greedy${NC}"
        else
            brew upgrade --cask --greedy
        fi
    else
        if [ "$DRY_RUN" = true ]; then
            echo "${CYAN}[DRY RUN] Would run: brew upgrade --cask${NC}"
        else
            brew upgrade --cask
        fi
    fi
else
    printf "\n${GREEN}All casks are already up to date.${NC}\n"
fi

# 5. Remove unused dependencies
printf "\n${BLUE}==>${NC} ${BOLD}Removing unused dependencies (autoremove)...${NC}\n"
if [ "$DRY_RUN" = true ]; then
    echo "${CYAN}[DRY RUN] Would run: brew autoremove${NC}"
else
    brew autoremove
fi

# 6. Cleanup old versions and downloads
printf "\n${BLUE}==>${NC} ${BOLD}Cleaning up Homebrew...${NC}\n"
if [ "$DRY_RUN" = true ]; then
    echo "${CYAN}[DRY RUN] Would run: brew cleanup -s${NC}"
else
    brew cleanup -s
fi

# 7. Optional: Remove old cached downloads
if ask_user "Do you want to remove old cached downloads from ~/Library/Caches/Homebrew?"; then
    echo "Removing old cached downloads..."
    _cache_dir="${HOME:-}/Library/Caches/Homebrew"
    if [ -n "${HOME:-}" ] && [ -d "$_cache_dir" ]; then
        if [ "$DRY_RUN" = true ]; then
            echo "${CYAN}[DRY RUN] Would run: rm -rf \"$_cache_dir/\"*${NC}"
        else
            rm -rf "${_cache_dir:?}"/* 2>/dev/null || true
        fi
    else
        echo "Home directory or cache directory not found. Skipping."
    fi
else
    echo "Skipping removal of Homebrew cache."
fi

# 8. Check for any services that might need a restart
if command -v brew services >/dev/null 2>&1; then
    printf "\n${BLUE}==>${NC} ${BOLD}Checking Homebrew services...${NC}\n"
    # Check if any services are started
    if brew services list | grep -q "started"; then
        echo "${YELLOW}Note: Some services are running. If they were updated, they may need a restart.${NC}"
        if ask_user "Would you like to see the list of running services?"; then
            brew services list
        fi
        if ask_user "Would you like to restart all started Homebrew services to apply any updates?"; then
            if [ "$DRY_RUN" = true ]; then
                echo "${CYAN}[DRY RUN] Would restart all started services${NC}"
            else
                brew services list | grep "started" | awk '{print $1}' | while read -r svc; do
                    echo "Restarting service: $svc..."
                    brew services restart "$svc"
                done
            fi
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

# Capture partition available space after cleanup (in KB)
DISK_AFTER=$(df -k "${HOME:-/}" 2>/dev/null | tail -1 | awk '{print $4}')
DISK_AFTER=${DISK_AFTER:-0}

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
HUMAN_SAVED=$(human_readable "$CLEARED")

PART_CLEARED=$((DISK_AFTER - DISK_BEFORE))
if [ "$PART_CLEARED" -lt 0 ]; then PART_CLEARED=0; fi
HUMAN_PART_SAVED=$(human_readable "$PART_CLEARED")

printf "\n${BOLD}${CYAN}========== CLEANUP SUMMARY ==========${NC}\n"
echo "${CYAN}Homebrew cache cleared  : ${BOLD}$HUMAN_SAVED${NC}"
echo "${CYAN}Total partition cleared : ${BOLD}$HUMAN_PART_SAVED${NC}"
echo "${BOLD}${CYAN}=====================================${NC}"

# Optional terminal history clearing
if ask_user "Do you want to clear terminal history?"; then
    echo "Clearing terminal history..."
    if [ "$DRY_RUN" = true ]; then
        echo "${CYAN}[DRY RUN] Would clear terminal history files${NC}"
    else
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
    fi
else
    echo "Skipping terminal history clear."
fi

printf "\n${GREEN}%s - Homebrew system update completed successfully.${NC}\n" "$(date)"

# Send desktop notification
if [ "$PART_CLEARED" -gt "$CLEARED" ]; then
    send_notification "Maintenance Complete! $HUMAN_PART_SAVED recovered."
else
    send_notification "Maintenance Complete! $HUMAN_SAVED recovered."
fi
