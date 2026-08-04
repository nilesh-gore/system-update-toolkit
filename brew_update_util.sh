#!/bin/sh
# Brew System Update Utility - macOS
# A premium, interactive script to keep your Homebrew environment in top shape.

SCRIPT_VERSION="2.7.1"
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

set -u

# Color definitions for a premium look
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m' # No Color
TOTAL_STEPS=9

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

# Check for Low Storage Alert (10 GB threshold = 10485760 KB)
if [ "$DISK_BEFORE" -gt 0 ] && [ "$DISK_BEFORE" -lt 10485760 ]; then
    DISK_GB=$(awk -v k="$DISK_BEFORE" 'BEGIN {printf "%.2f", k/1024/1024}')
    printf "${RED}⚠️  WARNING: Low Disk Space! Only ${DISK_GB} GB available on system partition.${NC}\n"
    printf "${YELLOW}Your system may experience severe slowdowns. Running toolkit to recover space is highly recommended!${NC}\n\n"
    send_notification "⚠️ Low Disk Space! Only ${DISK_GB} GB remaining."
fi

# 1. Update Homebrew
printf "\n${BLUE}==>${NC} ${BOLD}[Step 1/${TOTAL_STEPS}] Updating Homebrew definitions...${NC}\n"
if [ "$DRY_RUN" = true ]; then
    echo "${CYAN}[DRY RUN] Would run: brew update${NC}"
else
    if brew update; then
        printf "${GREEN}  ✔ Homebrew definitions updated.${NC}\n"
    else
        printf "${RED}  ✘ Homebrew update encountered errors. Continuing...${NC}\n"
    fi
fi

# 2. Check for outdated packages
printf "\n${BLUE}==>${NC} ${BOLD}[Step 2/${TOTAL_STEPS}] Checking for outdated packages...${NC}\n"
OUTDATED_FORMULAE=$(brew outdated --formula | wc -l | xargs)
OUTDATED_CASKS=$(brew outdated --cask | wc -l | xargs)

echo "${GREEN}  Found $OUTDATED_FORMULAE outdated formulae and $OUTDATED_CASKS outdated casks.${NC}"

# 3. Upgrade installed formulae
if [ "$OUTDATED_FORMULAE" -gt 0 ]; then
    printf "\n${BLUE}==>${NC} ${BOLD}[Step 3/${TOTAL_STEPS}] Upgrading installed formulae...${NC}\n"

    # Get the list of outdated formulae
    FORMULA_LIST=$(brew outdated --formula 2>/dev/null | awk '{print $1}')
    FORMULA_TOTAL=$(echo "$FORMULA_LIST" | grep -c . || true)

    if [ "$FORMULA_TOTAL" -gt 0 ]; then
        FORMULA_INDEX=0
        echo "$FORMULA_LIST" | while IFS= read -r formula; do
            FORMULA_INDEX=$((FORMULA_INDEX + 1))
            printf "\n${BLUE}  ==>${NC} ${BOLD}[%d/%d] Upgrading formula: ${CYAN}%s${NC}${BOLD}...${NC}\n" "$FORMULA_INDEX" "$FORMULA_TOTAL" "$formula"
            if [ "$DRY_RUN" = true ]; then
                echo "${CYAN}  [DRY RUN] Would run: brew upgrade $formula${NC}"
            else
                if brew upgrade "$formula"; then
                    printf "${GREEN}    ✔ %s upgraded successfully.${NC}\n" "$formula"
                else
                    printf "${RED}    ✘ %s upgrade failed. Continuing with remaining formulae...${NC}\n" "$formula"
                fi
            fi
        done
    fi
else
    printf "\n${BLUE}==>${NC} ${BOLD}[Step 3/${TOTAL_STEPS}] Upgrading installed formulae...${NC}\n"
    printf "${GREEN}  ✔ All formulae are already up to date.${NC}\n"
fi

# 4. Upgrade installed casks
if [ "$OUTDATED_CASKS" -gt 0 ]; then
    printf "\n${BLUE}==>${NC} ${BOLD}[Step 4/${TOTAL_STEPS}] Upgrading installed casks...${NC}\n"
    echo "${YELLOW}Tip: Greedy mode also upgrades casks that auto-update (Chrome, Slack, etc.).${NC}"
    GREEDY_FLAG=""
    if ask_user "Do you want to use greedy upgrade for casks?"; then
        GREEDY_FLAG="--greedy"
    fi

    # Get the list of outdated casks
    if [ -n "$GREEDY_FLAG" ]; then
        CASK_LIST=$(brew outdated --cask --greedy 2>/dev/null | awk '{print $1}')
    else
        CASK_LIST=$(brew outdated --cask 2>/dev/null | awk '{print $1}')
    fi

    CASK_TOTAL=$(echo "$CASK_LIST" | grep -c . || true)
    if [ "$CASK_TOTAL" -gt 0 ]; then
        CASK_INDEX=0
        echo "$CASK_LIST" | while IFS= read -r cask; do
            CASK_INDEX=$((CASK_INDEX + 1))
            printf "\n${BLUE}  ==>${NC} ${BOLD}[%d/%d] Upgrading cask: ${CYAN}%s${NC}${BOLD}...${NC}\n" "$CASK_INDEX" "$CASK_TOTAL" "$cask"
            if [ "$DRY_RUN" = true ]; then
                echo "${CYAN}  [DRY RUN] Would run: brew upgrade --cask $cask${NC}"
            else
                if brew upgrade --cask "$cask"; then
                    printf "${GREEN}    ✔ %s upgraded successfully.${NC}\n" "$cask"
                else
                    printf "${RED}    ✘ %s upgrade failed. Continuing with remaining casks...${NC}\n" "$cask"
                fi
            fi
        done
    else
        printf "${GREEN}  ✔ All casks are already up to date.${NC}\n"
    fi
else
    printf "\n${BLUE}==>${NC} ${BOLD}[Step 4/${TOTAL_STEPS}] Upgrading installed casks...${NC}\n"
    printf "${GREEN}  ✔ All casks are already up to date.${NC}\n"
fi

# 5. Remove unused dependencies
printf "\n${BLUE}==>${NC} ${BOLD}[Step 5/${TOTAL_STEPS}] Removing unused dependencies (autoremove)...${NC}\n"
if [ "$DRY_RUN" = true ]; then
    echo "${CYAN}[DRY RUN] Would run: brew autoremove${NC}"
else
    if brew autoremove; then
        printf "${GREEN}  ✔ Unused dependencies removed.${NC}\n"
    else
        printf "${RED}  ✘ Autoremove encountered errors. Continuing...${NC}\n"
    fi
fi

# 6. Cleanup old versions and downloads
printf "\n${BLUE}==>${NC} ${BOLD}[Step 6/${TOTAL_STEPS}] Cleaning up Homebrew...${NC}\n"
if [ "$DRY_RUN" = true ]; then
    echo "${CYAN}[DRY RUN] Would run: brew cleanup -s${NC}"
else
    if brew cleanup -s; then
        printf "${GREEN}  ✔ Homebrew cleanup complete.${NC}\n"
    else
        printf "${RED}  ✘ Cleanup encountered errors. Continuing...${NC}\n"
    fi
fi

# 7. Optional: Remove old cached downloads
printf "\n${BLUE}==>${NC} ${BOLD}[Step 7/${TOTAL_STEPS}] Remove old cached downloads${NC}\n"
if ask_user "Do you want to remove old cached downloads from ~/Library/Caches/Homebrew?"; then
    printf "${DIM}  Removing old cached downloads...${NC}\n"
    _cache_dir="${HOME:-}/Library/Caches/Homebrew"
    if [ -n "${HOME:-}" ] && [ -d "$_cache_dir" ]; then
        if [ "$DRY_RUN" = true ]; then
            echo "${CYAN}  [DRY RUN] Would run: rm -rf \"$_cache_dir/\"*${NC}"
        else
            rm -rf "${_cache_dir:?}"/* 2>/dev/null || true
            printf "${GREEN}  ✔ Cached downloads removed.${NC}\n"
        fi
    else
        printf "${YELLOW}  ⚠ Home directory or cache directory not found. Skipping.${NC}\n"
    fi
else
    printf "${DIM}  Skipped removal of Homebrew cache.${NC}\n"
fi

# 8. Check for any services that might need a restart
printf "\n${BLUE}==>${NC} ${BOLD}[Step 8/${TOTAL_STEPS}] Checking Homebrew services...${NC}\n"
if brew services list >/dev/null 2>&1; then
    # Check if any services are started
    if brew services list | grep -q "started"; then
        RUNNING_SVCS=$(brew services list | grep "started" | awk '{print $1}')
        SVC_COUNT=$(echo "$RUNNING_SVCS" | grep -c . || true)
        printf "${YELLOW}  Found %d running service(s). They may need a restart after updates.${NC}\n" "$SVC_COUNT"
        if ask_user "Would you like to see the list of running services?"; then
            brew services list
        fi
        if ask_user "Would you like to restart all started Homebrew services to apply any updates?"; then
            if [ "$DRY_RUN" = true ]; then
                echo "${CYAN}  [DRY RUN] Would restart all $SVC_COUNT started services${NC}"
            else
                SVC_INDEX=0
                echo "$RUNNING_SVCS" | while IFS= read -r svc; do
                    SVC_INDEX=$((SVC_INDEX + 1))
                    printf "${BLUE}  ==>${NC} ${BOLD}[%d/%d] Restarting service: ${CYAN}%s${NC}${BOLD}...${NC}\n" "$SVC_INDEX" "$SVC_COUNT" "$svc"
                    if brew services restart "$svc"; then
                        printf "${GREEN}    ✔ %s restarted.${NC}\n" "$svc"
                    else
                        printf "${RED}    ✘ %s restart failed.${NC}\n" "$svc"
                    fi
                done
            fi
        fi
    else
        printf "${GREEN}  ✔ No running services found.${NC}\n"
    fi
else
    printf "${DIM}  brew services not available. Skipping.${NC}\n"
fi

# 9. Optional: Run Brew Doctor
printf "\n${BLUE}==>${NC} ${BOLD}[Step 9/${TOTAL_STEPS}] Health check (brew doctor)${NC}\n"
if ask_user "Do you want to run 'brew doctor' to check for potential issues?"; then
    if [ "$DRY_RUN" = true ]; then
        echo "${CYAN}  [DRY RUN] Would run: brew doctor${NC}"
    else
        printf "${DIM}  Running brew doctor...${NC}\n"
        if brew doctor; then
            printf "${GREEN}  ✔ No issues found.${NC}\n"
        else
            printf "${YELLOW}  ⚠ Brew doctor found some issues (see above).${NC}\n"
        fi
    fi
else
    printf "${DIM}  Skipped health check.${NC}\n"
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
