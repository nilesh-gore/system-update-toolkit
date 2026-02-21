#!/bin/sh

echo "******** System Update Utility ********"

DEBIAN_FRONTEND=noninteractive
export DEBIAN_FRONTEND

echo "Collecting disk usage before cleanup..."

APT_CACHE_BEFORE=$(du -sb /var/cache/apt/archives 2>/dev/null | awk '{print $1}')
[ -z "$APT_CACHE_BEFORE" ] && APT_CACHE_BEFORE=0

APP_CACHE_BEFORE=$(du -sb /home/*/.cache 2>/dev/null | awk '{sum+=$1} END {print sum}')
[ -z "$APP_CACHE_BEFORE" ] && APP_CACHE_BEFORE=0

JOURNAL_BEFORE=$(journalctl --disk-usage --no-pager 2>/dev/null | \
    grep "disk space" | awk '{print $6}' | numfmt --from=iec 2>/dev/null)
[ -z "$JOURNAL_BEFORE" ] && JOURNAL_BEFORE=0

echo "Updating package list..."
sudo apt-get update -y

echo "Upgrading installed packages..."
sudo apt-get full-upgrade -y

echo "Installing missing dependencies (if any)..."
sudo apt-get install -f -y

echo "Reconfiguring any broken packages..."
sudo dpkg --configure -a

echo "Removing unnecessary packages..."
sudo apt-get autoremove --purge -y

echo "Cleaning up retrieved package files..."
sudo apt-get autoclean -y
sudo apt-get clean -y

echo "Clearing user application cache..."
sudo rm -rf /home/*/.cache/* 2>/dev/null

echo "Clearing thumbnail cache..."
sudo rm -rf /home/*/.cache/thumbnails/* 2>/dev/null
sudo rm -rf /home/*/.thumbnails/* 2>/dev/null

echo "Cleaning systemd journal logs (keeping last 7 days)..."
sudo journalctl --vacuum-time=7d

echo "Listing held packages..."
sudo apt-mark showhold

echo "Verifying package installation integrity..."
if command -v debsums >/dev/null 2>&1; then
    sudo debsums -s
else
    echo "debsums not installed, skipping integrity check."
fi

if command -v snap >/dev/null 2>&1; then
    echo "Updating Snap packages..."
    sudo snap refresh

    echo "Removing old Snap revisions..."
    snap list --all | awk '/disabled/{print $1, $3}' | while read snapname revision
    do
        echo "Removing old revision: $snapname (rev $revision)"
        sudo snap remove "$snapname" --revision="$revision"
    done
else
    echo "Snap is not installed."
fi

echo "Checking for system file inconsistencies..."
sudo apt-get check

APT_CACHE_AFTER=$(du -sb /var/cache/apt/archives 2>/dev/null | awk '{print $1}')
[ -z "$APT_CACHE_AFTER" ] && APT_CACHE_AFTER=0

APP_CACHE_AFTER=$(du -sb /home/*/.cache 2>/dev/null | awk '{sum+=$1} END {print sum}')
[ -z "$APP_CACHE_AFTER" ] && APP_CACHE_AFTER=0

JOURNAL_AFTER=$(journalctl --disk-usage --no-pager 2>/dev/null | \
    grep "disk space" | awk '{print $6}' | numfmt --from=iec 2>/dev/null)
[ -z "$JOURNAL_AFTER" ] && JOURNAL_AFTER=0

echo "========== CLEANUP SUMMARY =========="

APT_DIFF=$((APT_CACHE_BEFORE - APT_CACHE_AFTER))
APP_DIFF=$((APP_CACHE_BEFORE - APP_CACHE_AFTER))
JOURNAL_DIFF=$((JOURNAL_BEFORE - JOURNAL_AFTER))

numfmt --to=iec "$APT_DIFF" 2>/dev/null
numfmt --to=iec "$APP_DIFF" 2>/dev/null

echo "Journal size before: $(numfmt --to=iec "$JOURNAL_BEFORE" 2>/dev/null)"
echo "Journal size after : $(numfmt --to=iec "$JOURNAL_AFTER" 2>/dev/null)"
echo "Journal cleared    : $(numfmt --to=iec "$JOURNAL_DIFF" 2>/dev/null)"

echo "====================================="
echo "******** End of System Update Utility ********"

echo "Clear terminal history? (y/n): "
read CLEAR_HISTORY

case "$CLEAR_HISTORY" in
    y|Y)
        echo "Clearing terminal history..."
        history -c 2>/dev/null
        history -w 2>/dev/null
        ;;
    *)
        echo "Skipping terminal history clear."
        ;;
esac

echo "$(date) - System update completed successfully." | sudo tee -a /var/log/sysupdate.log
