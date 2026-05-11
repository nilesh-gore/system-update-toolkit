#!/bin/sh
# ============================================
# System Update Toolkit — Universal Installer
# https://github.com/nilesh-gore/system-update-toolkit
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/nilesh-gore/system-update-toolkit/main/install.sh | sh
#   wget -qO- https://raw.githubusercontent.com/nilesh-gore/system-update-toolkit/main/install.sh | sh
# ============================================

set -e

# --- Colors ---
RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
NC='\033[0m'

# --- Config ---
REPO_URL="https://github.com/nilesh-gore/system-update-toolkit.git"
INSTALL_DIR="$HOME/.system-update-toolkit"

echo ""
echo "${CYAN}**************************************************${NC}"
echo "${CYAN}*     System Update Toolkit — Installer          *${NC}"
echo "${CYAN}**************************************************${NC}"
echo ""

# --- Detect OS ---
detect_os() {
    case "$(uname -s)" in
        Linux*)
            if [ -f /etc/os-release ]; then
                . /etc/os-release
                if echo "$ID" | grep -qiE "debian|ubuntu|linuxmint|pop"; then
                    if [ -d /opt/google/cros-containers ] || grep -qi "chromeos" /proc/version 2>/dev/null; then
                        echo "chromeos"
                    else
                        echo "linux"
                    fi
                elif echo "$ID" | grep -qiE "fedora|centos|rhel|almalinux|rocky"; then
                    echo "fedora"
                else
                    echo "linux"
                fi
            else
                echo "linux"
            fi
            ;;
        Darwin*)
            echo "macos"
            ;;
        CYGWIN*|MINGW*|MSYS*)
            echo "windows"
            ;;
        *)
            echo "unknown"
            ;;
    esac
}

OS=$(detect_os)
echo "${GREEN}✅ Detected OS: ${OS}${NC}"
echo ""

# --- Check for git ---
if ! command -v git >/dev/null 2>&1; then
    echo "${RED}❌ Git is not installed. Please install git first.${NC}"
    echo ""
    case "$OS" in
        macos)   echo "  Run: xcode-select --install" ;;
        linux)   echo "  Run: sudo apt install git" ;;
        chromeos) echo "  Run: sudo apt install git" ;;
        *)       echo "  Install git from https://git-scm.com" ;;
    esac
    exit 1
fi

# --- Clone or update ---
if [ -d "$INSTALL_DIR" ]; then
    echo "${YELLOW}📁 Toolkit already installed at $INSTALL_DIR${NC}"
    echo "${CYAN}===> Updating to latest version...${NC}"
    cd "$INSTALL_DIR"
    git pull --quiet
    echo "${GREEN}✅ Updated successfully!${NC}"
else
    echo "${CYAN}===> Downloading System Update Toolkit...${NC}"
    git clone --quiet "$REPO_URL" "$INSTALL_DIR"
    echo "${GREEN}✅ Downloaded successfully!${NC}"
fi

echo ""

# --- Make scripts executable ---
chmod +x "$INSTALL_DIR"/*.sh 2>/dev/null || true

# --- Select and run the right script ---
case "$OS" in
    macos)
        SCRIPT="brew_update_util.sh"
        echo "${GREEN}🍎 macOS detected — ready to run: ${SCRIPT}${NC}"
        ;;
    linux)
        SCRIPT="update_util.sh"
        echo "${GREEN}🐧 Ubuntu/Debian detected — ready to run: ${SCRIPT}${NC}"
        echo "${YELLOW}   Note: This script requires sudo${NC}"
        ;;
    fedora)
        SCRIPT="fedora_update_util.sh"
        echo "${GREEN}🎩 Fedora/RHEL detected — ready to run: ${SCRIPT}${NC}"
        echo "${YELLOW}   Note: This script requires sudo${NC}"
        ;;
    chromeos)
        SCRIPT="chromeos_update_util.sh"
        echo "${GREEN}💻 ChromeOS detected — ready to run: ${SCRIPT}${NC}"
        ;;
    windows)
        echo "${GREEN}🪟 Windows detected${NC}"
        echo "${YELLOW}   Please run in PowerShell:${NC}"
        echo "   ${CYAN}powershell -File \"$INSTALL_DIR\\win_update_util.ps1\"${NC}"
        echo ""
        exit 0
        ;;
    *)
        echo "${RED}❌ Unsupported OS. Please run the scripts manually.${NC}"
        echo "   See: https://github.com/nilesh-gore/system-update-toolkit#-quick-start"
        exit 1
        ;;
esac

echo ""
echo "${CYAN}──────────────────────────────────────────${NC}"
echo "${CYAN}  Run it anytime with:${NC}"
echo "${GREEN}  $INSTALL_DIR/$SCRIPT${NC}"
echo "${CYAN}──────────────────────────────────────────${NC}"
echo ""

# --- Ask to run now ---
printf "${YELLOW}Would you like to run the update now? [y/N]: ${NC}"
read -r answer
case "$answer" in
    [yY]|[yY][eE][sS])
        echo ""
        if [ "$OS" = "linux" ] || [ "$OS" = "fedora" ]; then
            sudo "$INSTALL_DIR/$SCRIPT"
        else
            "$INSTALL_DIR/$SCRIPT"
        fi
        ;;
    *)
        echo ""
        echo "${GREEN}👍 No problem! Run it later with:${NC}"
        echo "   ${CYAN}$INSTALL_DIR/$SCRIPT${NC}"
        echo ""
        ;;
esac

echo "${GREEN}✅ System Update Toolkit is installed at: $INSTALL_DIR${NC}"
echo ""
echo "${CYAN}⭐ If you find this useful, please star the repo:${NC}"
echo "${CYAN}   https://github.com/nilesh-gore/system-update-toolkit${NC}"
echo ""
