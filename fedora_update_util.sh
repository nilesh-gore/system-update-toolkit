#!/bin/sh
# System Update Utility - Fedora/RHEL/CentOS
# A premium, robust script to keep your RPM-based Linux environment in top shape.

SCRIPT_VERSION="2.6"
AUTO_YES=false
DRY_RUN=false
NOTIFY=false

while [ "$#" -gt 0 ]; do
    case "$1" in
        -h|--help)
            echo "Usage: sudo ./fedora_update_util.sh [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  -h, --help       Show this help message and exit"
            echo "  -v, --version    Show version information"
            echo "  -y, --yes        Automatic yes to all prompts"
            echo "  -d, --dry-run    Show what would be done without making changes"
            echo "  --notify         Send desktop notification on completion"
            echo ""
            echo "A premium system update utility for Fedora/RHEL/CentOS."
            echo "Automates updates, cache cleanup, and disk recovery."
            exit 0
            ;;
        -v|--version)
            echo "System Update Utility (Fedora) v$SCRIPT_VERSION"
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
echo "${BOLD}${CYAN}*        Fedora System Update Utility            *${NC}"
echo "${BOLD}${CYAN}**************************************************${NC}"

# Check for dnf or dnf5
if command -v dnf5 >/dev/null 2>&1; then
    DNF_CMD="dnf5"
elif command -v dnf >/dev/null 2>&1; then
    DNF_CMD="dnf"
else
    echo "${RED}Error: dnf/dnf5 package manager not found. This script requires a Fedora/RHEL-based system.${NC}"
    exit 1
fi

printf "\n${BLUE}==>${NC} ${BOLD}Collecting disk usage before cleanup...${NC}\n"

# Capture DNF cache size (handles both dnf and dnf5)
DNF_CACHE_BEFORE=$(du -sb /var/cache/dnf /var/cache/dnf5 2>/dev/null | awk '{sum+=$1} END {print sum}')
[ -z "$DNF_CACHE_BEFORE" ] && DNF_CACHE_BEFORE=0

APP_CACHE_BEFORE=$(du -sb /home/*/.cache 2>/dev/null | awk '{sum+=$1} END {print sum}')
[ -z "$APP_CACHE_BEFORE" ] && APP_CACHE_BEFORE=0

JOURNAL_BEFORE=$(journalctl --disk-usage --no-pager 2>/dev/null | grep "disk space" | awk '{print $6}' | numfmt --from=iec 2>/dev/null || echo 0)
[ -z "$JOURNAL_BEFORE" ] && JOURNAL_BEFORE=0

DISK_BEFORE=$(df -B1 "${HOME:-/}" 2>/dev/null | tail -1 | awk '{print $4}')
[ -z "$DISK_BEFORE" ] && DISK_BEFORE=0

# Check for Low Storage Alert (10 GB threshold in bytes)
if [ "$DISK_BEFORE" -gt 0 ] && [ "$DISK_BEFORE" -lt 10737418240 ]; then
    DISK_GB=$(numfmt --to=iec "$DISK_BEFORE" 2>/dev/null || echo "$DISK_BEFORE bytes")
    printf "${RED}⚠️  WARNING: Low Disk Space! Only ${DISK_GB} available on system partition.${NC}\n"
    printf "${YELLOW}Your system may experience severe slowdowns. Running toolkit to recover space is highly recommended!${NC}\n\n"
    send_notification "⚠️ Low Disk Space! Only ${DISK_GB} remaining."
fi

echo "${BLUE}==>${NC} ${BOLD}Refreshing package metadata and upgrading system via $DNF_CMD...${NC}"
if [ "$DRY_RUN" = true ]; then
    echo "${CYAN}[DRY RUN] Would run: sudo $DNF_CMD upgrade --refresh -y${NC}"
else
    sudo $DNF_CMD upgrade --refresh -y
fi

echo "${BLUE}==>${NC} ${BOLD}Removing unnecessary packages...${NC}"
if [ "$DRY_RUN" = true ]; then
    echo "${CYAN}[DRY RUN] Would run: sudo $DNF_CMD autoremove -y${NC}"
else
    sudo $DNF_CMD autoremove -y
fi

echo "${BLUE}==>${NC} ${BOLD}Cleaning up $DNF_CMD cache...${NC}"
if [ "$DRY_RUN" = true ]; then
    echo "${CYAN}[DRY RUN] Would run: sudo $DNF_CMD clean all${NC}"
else
    sudo $DNF_CMD clean all
fi

if ask_user "Do you want to clear user application caches (~/.cache)?"; then
    echo "${BLUE}==>${NC} ${BOLD}Clearing user application cache...${NC}"
    if [ "$DRY_RUN" = true ]; then
        echo "${CYAN}[DRY RUN] Would run: sudo rm -rf /home/*/.cache/*${NC}"
    else
        sudo rm -rf /home/*/.cache/* 2>/dev/null || true
    fi

    echo "${BLUE}==>${NC} ${BOLD}Clearing thumbnail cache...${NC}"
    if [ "$DRY_RUN" = true ]; then
        echo "${CYAN}[DRY RUN] Would run: sudo rm -rf /home/*/.cache/thumbnails/* && sudo rm -rf /home/*/.thumbnails/*${NC}"
    else
        sudo rm -rf /home/*/.cache/thumbnails/* 2>/dev/null || true
        sudo rm -rf /home/*/.thumbnails/* 2>/dev/null || true
    fi
else
    echo "Skipping user cache cleanup."
fi

echo "${BLUE}==>${NC} ${BOLD}Cleaning systemd journal logs (keeping last 7 days)...${NC}"
if [ "$DRY_RUN" = true ]; then
    echo "${CYAN}[DRY RUN] Would run: sudo journalctl --vacuum-time=7d${NC}"
else
    sudo journalctl --vacuum-time=7d
fi

if command -v flatpak >/dev/null 2>&1; then
    printf "\n${BLUE}==>${NC} ${BOLD}Updating Flatpak packages...${NC}\n"
    if [ "$DRY_RUN" = true ]; then
        echo "${CYAN}[DRY RUN] Would run: sudo flatpak update -y${NC}"
    else
        sudo flatpak update -y
    fi
    
    echo "${BLUE}==>${NC} ${BOLD}Removing unused Flatpak runtimes...${NC}"
    if [ "$DRY_RUN" = true ]; then
        echo "${CYAN}[DRY RUN] Would run: sudo flatpak uninstall --unused -y${NC}"
    else
        sudo flatpak uninstall --unused -y
    fi
else
    printf "\n${YELLOW}Flatpak is not installed. Skipping.${NC}\n"
fi

if command -v snap >/dev/null 2>&1; then
    printf "\n${BLUE}==>${NC} ${BOLD}Updating Snap packages...${NC}\n"
    if [ "$DRY_RUN" = true ]; then
        echo "${CYAN}[DRY RUN] Would run: sudo snap refresh${NC}"
    else
        sudo snap refresh
    fi

    echo "${BLUE}==>${NC} ${BOLD}Removing old Snap revisions...${NC}"
    snap list --all | awk '/disabled/{print $1, $3}' | while read -r snapname revision
    do
        echo "Removing old revision: $snapname (rev $revision)"
        if [ "$DRY_RUN" = true ]; then
            echo "${CYAN}[DRY RUN] Would run: sudo snap remove \"$snapname\" --revision=\"$revision\"${NC}"
        else
            sudo snap remove "$snapname" --revision="$revision" || true
        fi
    done
fi

DNF_CACHE_AFTER=$(du -sb /var/cache/dnf /var/cache/dnf5 2>/dev/null | awk '{sum+=$1} END {print sum}')
[ -z "$DNF_CACHE_AFTER" ] && DNF_CACHE_AFTER=0

APP_CACHE_AFTER=$(du -sb /home/*/.cache 2>/dev/null | awk '{sum+=$1} END {print sum}')
[ -z "$APP_CACHE_AFTER" ] && APP_CACHE_AFTER=0

JOURNAL_AFTER=$(journalctl --disk-usage --no-pager 2>/dev/null | grep "disk space" | awk '{print $6}' | numfmt --from=iec 2>/dev/null || echo 0)
[ -z "$JOURNAL_AFTER" ] && JOURNAL_AFTER=0

DISK_AFTER=$(df -B1 "${HOME:-/}" 2>/dev/null | tail -1 | awk '{print $4}')
[ -z "$DISK_AFTER" ] && DISK_AFTER=0

printf "\n${BOLD}${CYAN}========== CLEANUP SUMMARY ==========${NC}\n"

DNF_DIFF=$((DNF_CACHE_BEFORE - DNF_CACHE_AFTER))
APP_DIFF=$((APP_CACHE_BEFORE - APP_CACHE_AFTER))
JOURNAL_DIFF=$((JOURNAL_BEFORE - JOURNAL_AFTER))

[ "$DNF_DIFF" -lt 0 ] && DNF_DIFF=0
[ "$APP_DIFF" -lt 0 ] && APP_DIFF=0
[ "$JOURNAL_DIFF" -lt 0 ] && JOURNAL_DIFF=0

TOTAL_SAVED=$((DNF_DIFF + APP_DIFF + JOURNAL_DIFF))
HUMAN_TOTAL=$(numfmt --to=iec "$TOTAL_SAVED" 2>/dev/null || echo "$TOTAL_SAVED bytes")

PART_CLEARED=$((DISK_AFTER - DISK_BEFORE))
[ "$PART_CLEARED" -lt 0 ] && PART_CLEARED=0
HUMAN_PART_SAVED=$(numfmt --to=iec "$PART_CLEARED" 2>/dev/null || echo "$PART_CLEARED bytes")

echo "DNF cache cleared     : ${BOLD}$(numfmt --to=iec "$DNF_DIFF" 2>/dev/null || echo "$DNF_DIFF bytes")${NC}"
echo "App cache cleared     : ${BOLD}$(numfmt --to=iec "$APP_DIFF" 2>/dev/null || echo "$APP_DIFF bytes")${NC}"
echo "Journal cleared       : ${BOLD}$(numfmt --to=iec "$JOURNAL_DIFF" 2>/dev/null || echo "$JOURNAL_DIFF bytes")${NC}"
echo "-------------------------------------"
echo "Specific Caches Saved : ${BOLD}${GREEN}$HUMAN_TOTAL${NC}"
echo "Total Partition Saved : ${BOLD}${GREEN}$HUMAN_PART_SAVED${NC}"
echo "${BOLD}${CYAN}=====================================${NC}"

# Optional terminal history clearing
if ask_user "Do you want to clear terminal history?"; then
    echo "Clearing terminal history..."
    if [ "$DRY_RUN" = true ]; then
        echo "${CYAN}[DRY RUN] Would clear terminal history files${NC}"
    else
        for f in "$HOME/.bash_history" "$HOME/.zsh_history"; do
            if [ -f "$f" ]; then
                : >"$f"
                echo "Cleared $f"
            fi
        done
    fi
else
    echo "Skipping terminal history clear."
fi

printf "\n${GREEN}%s - Fedora system update completed successfully.${NC}\n" "$(date)" | sudo tee -a /var/log/sysupdate.log

# Send desktop notification
if [ "$PART_CLEARED" -gt "$TOTAL_SAVED" ]; then
    send_notification "Maintenance Complete! $HUMAN_PART_SAVED recovered."
else
    send_notification "Maintenance Complete! $HUMAN_TOTAL recovered."
fi
