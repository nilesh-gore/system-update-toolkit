#!/bin/bash

echo "******** System Update Utility ********"

export DEBIAN_FRONTEND=noninteractive

# =======================
# Capture sizes BEFORE cleanup
# =======================

echo "Collecting disk usage before cleanup..."

APT_CACHE_BEFORE=$(du -sb /var/cache/apt/archives 2>/dev/null | awk '{print $1}')
APT_CACHE_BEFORE=${APT_CACHE_BEFORE:-0}

APP_CACHE_BEFORE=$(du -sb /home/*/.cache 2>/dev/null | awk '{sum+=$1} END {print sum}')
APP_CACHE_BEFORE=${APP_CACHE_BEFORE:-0}

# Fixed journal size to numeric bytes
JOURNAL_BEFORE=$(journalctl --disk-usage --no-pager 2>/dev/null | grep "disk space" | awk '{print $6}' | numfmt --from=iec)
JOURNAL_BEFORE=${JOURNAL_BEFORE:-0}

# =======================
# Original update & cleanup steps
# =======================

echo "Updating package list..."
sudo apt-get update -y

echo "Upgrading installed packages..."
sudo apt-get full-upgrade -y

echo "Performing distribution upgrade (if available)..."
sudo apt-get full-upgrade -y

echo "Installing missing dependencies (if any)..."
sudo apt-get install -f -y

echo "Reconfiguring any broken packages..."
sudo dpkg --configure -a

echo "Removing unnecessary packages..."
sudo apt-get autoremove --purge -y

echo "Cleaning up retrieved package files..."
sudo apt-get autoclean -y

echo "Removing cached package files to save space..."
sudo apt-get clean -y

# =======================
# Clear user/application caches (safe)
# =======================

echo "Clearing user application cache..."
sudo rm -rf /home/*/.cache/* 2>/dev/null || true

echo "Clearing thumbnail cache..."
sudo rm -rf /home/*/.cache/thumbnails/* 2>/dev/null || true
sudo rm -rf /home/*/.thumbnails/* 2>/dev/null || true

echo "Cleaning systemd journal logs (keeping last 7 days)..."
sudo journalctl --vacuum-time=7d

# =======================
# Continue original steps
# =======================

echo "Listing held (protected) packages..."
sudo apt-mark showhold

echo "Verifying package installation integrity..."
sudo debsums -s || echo "debsums not installed, skipping integrity check."

if command -v snap &> /dev/null; then
    echo "Updating Snap packages..."
    sudo snap refresh

    echo "Removing old and duplicate Snap packages..."
    set -eu
    snap list --all | awk '/disabled/{print $1, $3}' | while read snapname revision; do
        echo "Removing old revision: $snapname (rev $revision)"
        sudo snap remove "$snapname" --revision="$revision"
    done
else
    echo "Snap is not installed on this system."
fi

echo "Checking for system file inconsistencies..."
sudo apt-get check

# =======================
# Capture sizes AFTER cleanup
# =======================

APT_CACHE_AFTER=$(du -sb /var/cache/apt/archives 2>/dev/null | awk '{print $1}')
APT_CACHE_AFTER=${APT_CACHE_AFTER:-0}

APP_CACHE_AFTER=$(du -sb /home/*/.cache 2>/dev/null | awk '{sum+=$1} END {print sum}')
APP_CACHE_AFTER=${APP_CACHE_AFTER:-0}

# Fixed journal size to numeric bytes
JOURNAL_AFTER=$(journalctl --disk-usage --no-pager 2>/dev/null | grep "disk space" | awk '{print $6}' | numfmt --from=iec)
JOURNAL_AFTER=${JOURNAL_AFTER:-0}

# =======================
# Display cleanup summary
# =======================

echo "========== CLEANUP SUMMARY =========="

echo "APT cache cleared:"
numfmt --to=iec $((APT_CACHE_BEFORE - APT_CACHE_AFTER))

echo "Application cache cleared:"
numfmt --to=iec $((APP_CACHE_BEFORE - APP_CACHE_AFTER))

echo "Journal size before: $(numfmt --to=iec $JOURNAL_BEFORE)"
echo "Journal size after : $(numfmt --to=iec $JOURNAL_AFTER)"
echo "Journal cleared    : $(numfmt --to=iec $((JOURNAL_BEFORE - JOURNAL_AFTER)))"

echo "====================================="

echo "******** End of System Update Utility ********"

# Prompt for clearing terminal history
read -p "Would you like to clear the terminal history (y/n)? " CLEAR_HISTORY
if [[ "$CLEAR_HISTORY" =~ ^[Yy]$ ]]; then
    echo "Clearing terminal history..."
    history -c
    history -w
fi

echo "$(date) - System update completed successfully." | sudo tee -a /var/log/sysupdate.log
