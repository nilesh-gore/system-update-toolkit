#!/bin/sh
# Brew System Update Utility - macOS
# Updates brew, upgrades formulae and casks, cleans caches, optional terminal history clearing
# Optionally removes old cached downloads from ~/Library/Caches/Homebrew

echo "******** Homebrew System Update Utility ********"

# Capture disk usage before cleanup
BREW_CACHE_BEFORE=$(du -sb "$(brew --cache)" 2>/dev/null | awk '{print $1}')
BREW_CACHE_BEFORE=${BREW_CACHE_BEFORE:-0}

# Update Homebrew
echo "Updating Homebrew..."
brew update

# Upgrade installed formulae and casks
echo "Upgrading installed formulae..."
brew upgrade
echo "Upgrading installed casks..."
brew upgrade --cask

# Cleanup old versions
echo "Cleaning up Homebrew..."
brew cleanup

# Optional: Remove old cached downloads
echo "Do you want to remove old cached downloads from ~/Library/Caches/Homebrew? (y/n): "
read REMOVE_CACHE
case "$REMOVE_CACHE" in
    y|Y)
        echo "Removing old cached downloads..."
        rm -rf ~/Library/Caches/Homebrew/* 2>/dev/null
        ;;
    *)
        echo "Skipping removal of Homebrew cache."
        ;;
esac

# Capture disk usage after cleanup
BREW_CACHE_AFTER=$(du -sb "$(brew --cache)" 2>/dev/null | awk '{print $1}')
BREW_CACHE_AFTER=${BREW_CACHE_AFTER:-0}

# Display summary
CLEARED=$((BREW_CACHE_BEFORE - BREW_CACHE_AFTER))
echo "========== CLEANUP SUMMARY =========="
echo "Homebrew cache cleared: $(numfmt --to=iec $CLEARED)"
echo "====================================="

# Optional terminal history clearing
echo "Do you want to clear terminal history? (y/n): "
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

echo "$(date) - Homebrew system update completed successfully."
