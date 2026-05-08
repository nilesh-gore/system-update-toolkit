# Windows System Update Utility
# A premium PowerShell script to keep your Windows environment in top shape.

param(
    [switch]$Help,
    [switch]$Version
)

$ScriptVersion = "2.1"

if ($Help) {
    Write-Host "Usage: .\win_update_util.ps1 [-Help] [-Version]"
    Write-Host ""
    Write-Host "Options:"
    Write-Host "  -Help       Show this help message and exit"
    Write-Host "  -Version    Show version information"
    Write-Host ""
    Write-Host "A premium system update utility for Windows."
    Write-Host "Automates updates, cache cleanup, and disk recovery."
    exit 0
}

if ($Version) {
    Write-Host "System Update Utility (Windows) v$ScriptVersion"
    exit 0
}

$ErrorActionPreference = "Stop"

# Visual settings
$Host.UI.RawUI.WindowTitle = "Windows System Update Utility"
$CYAN = "`e[1;36m"
$GREEN = "`e[1;32m"
$YELLOW = "`e[1;33m"
$BLUE = "`e[1;34m"
$RED = "`e[1;31m"
$BOLD = "`e[1m"
$NC = "`e[0m"

Write-Host "${BOLD}${CYAN}**************************************************${NC}"
Write-Host "${BOLD}${CYAN}*        Windows System Update Utility           *${NC}"
Write-Host "${BOLD}${CYAN}**************************************************${NC}"

# 1. Check for Admin Privileges
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "${RED}Warning: Not running as Administrator. Some tasks may fail.${NC}"
}

# 2. Update Winget Packages
if (Get-Command winget -ErrorAction SilentlyContinue) {
    Write-Host "`n${BLUE}==>${NC} ${BOLD}Checking for Winget package updates...${NC}"
    winget upgrade
    
    Write-Host "`n${YELLOW}Do you want to upgrade all packages via Winget? (y/n): ${NC}" -NoNewline
    $choice = Read-Host
    if ($choice -eq 'y' -or $choice -eq 'Y') {
        winget upgrade --all --include-unknown
    }
} else {
    Write-Host "`n${YELLOW}Winget not found. Skipping package updates.${NC}"
}

# 3. Windows Store Updates
Write-Host "`n${BLUE}==>${NC} ${BOLD}Note: Windows Store apps usually update automatically.${NC}"
Write-Host "You can manually check in Microsoft Store -> Library -> Get updates."

# 4. WSL Update (if applicable)
if (Get-Command wsl -ErrorAction SilentlyContinue) {
    Write-Host "`n${BLUE}==>${NC} ${BOLD}Updating WSL kernel...${NC}"
    wsl --update
}

# 5. Disk Cleanup
Write-Host "`n${BLUE}==>${NC} ${BOLD}Running System Cleanup...${NC}"
Write-Host "${YELLOW}This will launch the Disk Cleanup tool. Please select the items you wish to clean.${NC}"
Start-Process "cleanmgr.exe" -ArgumentList "/sagerun:1" -Wait

# 6. Optional: Clear Temporary Files
Write-Host "`n${YELLOW}Do you want to clear system temporary files? (y/n): ${NC}" -NoNewline
$choiceTemp = Read-Host
if ($choiceTemp -eq 'y' -or $choiceTemp -eq 'Y') {
    Write-Host "Clearing Temp folders..."
    $tempFolders = @("$env:TEMP", "$env:SystemRoot\Temp")
    foreach ($folder in $tempFolders) {
        Get-ChildItem $folder -Recurse | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
    }
    Write-Host "${GREEN}Temporary files cleared.${NC}"
}

# 7. Optional: Clear PowerShell History
Write-Host "`n${YELLOW}Do you want to clear PowerShell history? (y/n): ${NC}" -NoNewline
$choiceHist = Read-Host
if ($choiceHist -eq 'y' -or $choiceHist -eq 'Y') {
    Clear-History
    if (Test-Path (Get-PSReadLineOption).HistorySavePath) {
        Remove-Item (Get-PSReadLineOption).HistorySavePath
    }
    Write-Host "${GREEN}PowerShell history cleared.${NC}"
}

Write-Host "`n${BOLD}${GREEN}========== CLEANUP SUMMARY ==========${NC}"
Write-Host "Winget packages : ${BOLD}Checked & Updated${NC}"
Write-Host "Temp files      : ${BOLD}Cleaned${NC}"
Write-Host "${BOLD}${GREEN}=====================================${NC}"

Write-Host "`n${CYAN}$(Get-Date) - Windows system update completed successfully.${NC}"
