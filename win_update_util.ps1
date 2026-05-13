# Windows System Update Utility
# A premium PowerShell script to keep your Windows environment in top shape.

param(
    [Alias("y")]
    [switch]$Yes,
    [Alias("d")]
    [switch]$DryRun,
    [switch]$Notify,
    [switch]$Help,
    [switch]$Version
)

$ScriptVersion = "2.4"
$script:AutoYes = $Yes
$script:IsDryRun = $DryRun
$script:NotifyUser = $Notify

if ($Help) {
    Write-Host "Usage: .\win_update_util.ps1 [-Yes] [-DryRun] [-Notify] [-Help] [-Version]"
    Write-Host ""
    Write-Host "Options:"
    Write-Host "  -Yes, -y    Automatic yes to all prompts"
    Write-Host "  -DryRun, -d Show what would be done without making changes"
    Write-Host "  -Notify     Send desktop notification on completion"
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

# Helper function: prompt user with y/n/a support
function Confirm-Action {
    param([string]$Prompt)
    if ($script:AutoYes) { return $true }
    Write-Host "`n${YELLOW}$Prompt${NC}"
    Write-Host "${BOLD}[y]es / [n]o / [a]ll${NC}: " -NoNewline
    $reply = Read-Host
    switch ($reply) {
        { $_ -match '^a(ll)?$' } { $script:AutoYes = $true; return $true }
        { $_ -match '^y(es)?$' } { return $true }
        default { return $false }
    }
}

# Visual settings
$Host.UI.RawUI.WindowTitle = "Windows System Update Utility"
$CYAN = "`e[1;36m"
$GREEN = "`e[1;32m"
$YELLOW = "`e[1;33m"
$BLUE = "`e[1;34m"
$RED = "`e[1;31m"
$BOLD = "`e[1m"
$NC = "`e[0m"

function Send-Notification {
    param([string]$Message)
    if ($script:NotifyUser) {
        # msg is available on Pro/Enterprise. Silent fail on Home.
        msg * /TIME:10 "📦 System Update Toolkit: $Message" 2>$null
    }
}

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

    if (Confirm-Action "Do you want to upgrade all packages via Winget?") {
        if ($script:IsDryRun) {
            Write-Host "${CYAN}[DRY RUN] Would run: winget upgrade --all --include-unknown${NC}"
        } else {
            winget upgrade --all --include-unknown
        }
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
    if ($script:IsDryRun) {
        Write-Host "${CYAN}[DRY RUN] Would run: wsl --update${NC}"
    } else {
        wsl --update
    }
}

# 5. Disk Cleanup
Write-Host "`n${BLUE}==>${NC} ${BOLD}Running System Cleanup...${NC}"
if ($script:IsDryRun) {
    Write-Host "${CYAN}[DRY RUN] Would launch: cleanmgr.exe /sagerun:1${NC}"
} else {
    Write-Host "${YELLOW}This will launch the Disk Cleanup tool. Please select the items you wish to clean.${NC}"
    Start-Process "cleanmgr.exe" -ArgumentList "/sagerun:1" -Wait
}

# 6. Optional: Clear Temporary Files
if (Confirm-Action "Do you want to clear system temporary files?") {
    Write-Host "Clearing Temp folders..."
    $tempFolders = @("$env:TEMP", "$env:SystemRoot\Temp")
    foreach ($folder in $tempFolders) {
        if ($script:IsDryRun) {
            Write-Host "${CYAN}[DRY RUN] Would clear folder: $folder${NC}"
        } else {
            Get-ChildItem $folder -Recurse | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
    Write-Host "${GREEN}Temporary files check complete.${NC}"
}

# 7. Optional: Clear PowerShell History
if (Confirm-Action "Do you want to clear PowerShell history?") {
    Write-Host "Clearing PowerShell history..."
    if ($script:IsDryRun) {
        Write-Host "${CYAN}[DRY RUN] Would clear PSReadline history and session history${NC}"
    } else {
        Clear-History
        if (Test-Path (Get-PSReadLineOption).HistorySavePath) {
            Remove-Item (Get-PSReadLineOption).HistorySavePath
        }
    }
    Write-Host "${GREEN}PowerShell history check complete.${NC}"
}

Write-Host "`n${BOLD}${CYAN}========== CLEANUP SUMMARY ==========${NC}"
Write-Host "Winget packages : ${BOLD}Checked & Updated${NC}"
Write-Host "System Cleanup  : ${BOLD}Run${NC}"
Write-Host "${BOLD}${CYAN}=====================================${NC}"

Write-Host "`n${GREEN}$(Get-Date) - Windows system update completed successfully.${NC}"

# Send desktop notification
Send-Notification "Maintenance Complete!"
