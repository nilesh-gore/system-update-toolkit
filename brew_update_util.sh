#!/bin/sh
# Brew System Update Utility - macOS

set -eu

echo "******** Homebrew System Update Utility ********"

# Check if Homebrew is installed
if ! command -v brew >/dev/null 2>&1; then
    echo "Homebrew is not installed. Please install Homebrew first."
    exit 1
fi

# Capture disk usage before cleanup (portable for macOS)
BREW_CACHE_BEFORE=$(du -sk "$(brew --cache)" 2>/dev/null | awk '{print $1}')
BREW_CACHE_BEFORE=${BREW_CACHE_BEFORE:-0}

# Update Homebrew
echo "Updating Homebrew..."
brew update

# Upgrade installed formulae and casks
echo "Upgrading installed formulae..."
brew upgrade
echo "Upgrading installed casks..."
brew upgrade --cask

# Cleanup old versions and downloads
echo "Cleaning up Homebrew..."
brew cleanup -s

# Optional: Remove old cached downloads
echo "Do you want to remove old cached downloads from ~/Library/Caches/Homebrew? (y/n): "
read REMOVE_CACHE
case "$REMOVE_CACHE" in
    y|Y)
        echo "Removing old cached downloads..."
        rm -rf "$HOME/Library/Caches/Homebrew/"* 2>/dev/null
        ;;
    *)
        echo "Skipping removal of Homebrew cache."
        ;;
esac

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
echo "========== CLEANUP SUMMARY =========="
echo "Homebrew cache cleared: $(human_readable "$CLEARED")"
echo "====================================="

# Optional terminal history clearing
echo "Do you want to clear terminal history? (y/n): "
read CLEAR_HISTORY
case "$CLEAR_HISTORY" in
    y|Y)
        echo "Clearing terminal history..."
        if [ -n "${HISTFILE:-}" ] && [ -f "$HISTFILE" ]; then
            > "$HISTFILE"
            echo "History file cleared."
        else
            echo "No history file found."
        fi
        ;;
    *)
        echo "Skipping terminal history clear."
        ;;
esac

echo "$(date) - Homebrew system update completed successfully."
