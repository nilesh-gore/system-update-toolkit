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

$ScriptVersion = "2.6.1"
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

# Visual settings
# Built from [char]27 rather than the `e escape token, which Windows
# PowerShell 5.1 (the documented minimum supported version) does not
# recognize and would print literally instead of rendering as color.
$Host.UI.RawUI.WindowTitle = "Windows System Update Utility"
$Esc = [char]27
$CYAN = "$Esc[1;36m"
$GREEN = "$Esc[1;32m"
$YELLOW = "$Esc[1;33m"
$BLUE = "$Esc[1;34m"
$RED = "$Esc[1;31m"
$BOLD = "$Esc[1m"
$NC = "$Esc[0m"

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

function Send-Notification {
    param([string]$Message)
    if ($script:NotifyUser) {
        try {
            Add-Type -AssemblyName System.Windows.Forms, System.Drawing
            $objNotifyIcon = New-Object System.Windows.Forms.NotifyIcon
            $objNotifyIcon.Icon = [System.Drawing.SystemIcons]::Information
            $objNotifyIcon.BalloonTipIcon = "Info"
            $objNotifyIcon.BalloonTipText = "Maintenance Complete! $Message"
            $objNotifyIcon.BalloonTipTitle = "System Update Toolkit"
            $objNotifyIcon.Visible = $true
            $objNotifyIcon.ShowBalloonTip(10000)
        } catch {
            # Fallback to msg command if UI assemblies fail (e.g. headless/Server)
            msg * /TIME:10 "📦 System Update Toolkit: $Message" 2>$null
        }
    }
}

Write-Host "${BOLD}${CYAN}**************************************************${NC}"
Write-Host "${BOLD}${CYAN}*        Windows System Update Utility           *${NC}"
Write-Host "${BOLD}${CYAN}**************************************************${NC}"

# 1. Check for Admin Privileges (Windows only)
$script:IsAdministrator = $false
if ($IsWindows -ne $false) {
    $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    if ($currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        $script:IsAdministrator = $true
    } else {
        Write-Host "${RED}Warning: Not running as Administrator. Some tasks may fail.${NC}"
    }
}

# 1.5 Check for Low Storage Alert (10 GB threshold = 10737418240 bytes)
$systemDrive = $env:SystemDrive
$driveInfo = Get-PSDrive -Name $systemDrive[0] -ErrorAction SilentlyContinue
$script:FreeBytesBefore = if ($driveInfo) { $driveInfo.Free } else { 0 }

if ($driveInfo -and $driveInfo.Free -lt 10737418240) {
    $freeGB = [Math]::Round($driveInfo.Free / 1GB, 2)
    Write-Host "${RED}⚠️  WARNING: Low Disk Space! Only ${freeGB} GB available on drive ${systemDrive}.${NC}"
    Write-Host "${YELLOW}Your system may experience severe slowdowns. Running toolkit to recover space is highly recommended!${NC}"
    Send-Notification "⚠️ Low Disk Space! Only ${freeGB} GB remaining."
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
$HasSageSet = $false
if (Test-Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches") {
    $keys = Get-ChildItem "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches" -ErrorAction SilentlyContinue
    foreach ($k in $keys) {
        if ($k.GetValue("StateFlags0001") -ne $null) {
            $HasSageSet = $true
            break
        }
    }
}
if (-not $HasSageSet -and $IsWindows -ne $false) {
    Write-Host "${YELLOW}Tip: Disk Cleanup preset 1 has not been configured. Running '/sagerun:1' might skip files.${NC}"
    Write-Host "To configure it, run this command once in an elevated shell: ${CYAN}cleanmgr.exe /sageset:1${NC}"
}
if ($script:IsDryRun) {
    Write-Host "${CYAN}[DRY RUN] Would launch: cleanmgr.exe /sagerun:1${NC}"
} else {
    Write-Host "${YELLOW}This will launch the Disk Cleanup tool. Please select the items you wish to clean.${NC}"
    Start-Process "cleanmgr.exe" -ArgumentList "/sagerun:1" -Wait
}

# 6. Optional: Clear Temporary Files
if (Confirm-Action "Do you want to clear system temporary files?") {
    Write-Host "Clearing Temp folders..."
    $tempFolders = @("$env:TEMP")
    if ($script:IsAdministrator -or $script:IsDryRun -or $IsWindows -eq $false) {
        $tempFolders += "$env:SystemRoot\Temp"
    } else {
        Write-Host "${YELLOW}⚠️  Skipping system-level Temp folder ($env:SystemRoot\Temp) because you are not running as Administrator.${NC}"
    }

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
    Write-Host "Clearing PowerShell persistent history file..."
    if ($script:IsDryRun) {
        Write-Host "${CYAN}[DRY RUN] Would clear PSReadline history file${NC}"
    } else {
        $histPath = (Get-PSReadLineOption).HistorySavePath
        if ($histPath -and (Test-Path $histPath)) {
            Clear-Content $histPath -ErrorAction SilentlyContinue
            Write-Host "${GREEN}PowerShell history file cleared successfully.${NC}"
        }
        Write-Host "${YELLOW}Note: Active terminal history in this session's window memory cannot be cleared by this script.${NC}"
        Write-Host "To clear it manually in your active shell, type: ${CYAN}Clear-History${NC}"
    }
}

# Calculate disk space metrics
$DriveAfter = Get-PSDrive -Name $systemDrive[0] -ErrorAction SilentlyContinue
$FreeBytesAfter = if ($DriveAfter) { $DriveAfter.Free } else { 0 }
$SavedBytes = if ($FreeBytesAfter -gt $script:FreeBytesBefore) { $FreeBytesAfter - $script:FreeBytesBefore } else { 0 }
$HumanSaved = "0 MB"
if ($SavedBytes -gt 0) {
    if ($SavedBytes -ge 1GB) {
        $HumanSaved = ([Math]::Round($SavedBytes / 1GB, 2)).ToString() + " GB"
    } else {
        $HumanSaved = ([Math]::Round($SavedBytes / 1MB, 2)).ToString() + " MB"
    }
}

Write-Host "`n${BOLD}${CYAN}========== CLEANUP SUMMARY ==========${NC}"
Write-Host "Winget packages   : ${BOLD}Checked & Updated${NC}"
Write-Host "System Cleanup    : ${BOLD}Run${NC}"
Write-Host "Total Disk Saved  : ${BOLD}${GREEN}$HumanSaved${NC}"
Write-Host "${BOLD}${CYAN}=====================================${NC}"

Write-Host "`n${GREEN}$(Get-Date) - Windows system update completed successfully.${NC}"

# Send desktop notification
Send-Notification "Maintenance Complete! $HumanSaved recovered."

