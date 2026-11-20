# Windows System Update Utility
# A premium PowerShell script to keep your Windows environment in top shape.

param(
    [Alias("y")]
    [switch]$Yes,
    [Alias("d")]
    [switch]$DryRun,
    [switch]$Notify,
    [switch]$ClearHistory,
    [switch]$DockerCleanup,
    [switch]$Help,
    [switch]$Version
)

$ScriptVersion = "3.2.0"
$script:AutoYes = $Yes
$script:IsDryRun = $DryRun
$script:NotifyUser = $Notify

if ($Help) {
    Write-Host "Usage: .\win_update_util.ps1 [-Yes] [-DryRun] [-Notify] [-ClearHistory] [-DockerCleanup] [-Help] [-Version]"
    Write-Host ""
    Write-Host "Options:"
    Write-Host "  -Yes, -y    Automatic yes to routine prompts (never to destructive ones)"
    Write-Host "  -DryRun, -d Show what would be done without making changes"
    Write-Host "  -Notify     Send desktop notification on completion"
    Write-Host "  -ClearHistory   Clear the PowerShell history file"
    Write-Host "  -DockerCleanup  Run 'docker system prune --volumes' (deletes unused volumes)"
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
try { $Host.UI.RawUI.WindowTitle = "Windows System Update Utility" } catch { Write-Debug "Window title not supported on this platform" }
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

# Destructive actions (history, Docker volumes) are never approved by -Yes or
# by answering "all": they need their own switch, or an explicit "y" at an
# interactive prompt.
function Confirm-Destructive {
    param(
        [bool]$Enabled,
        [string]$SwitchName,
        [string]$Prompt
    )
    if ($Enabled) { return $true }
    if ($Yes -or -not [Environment]::UserInteractive) {
        Write-Host "`n${YELLOW}Skipped (destructive): $Prompt${NC}"
        Write-Host "${YELLOW}Pass $SwitchName to run it; -Yes does not enable it.${NC}"
        return $false
    }
    Write-Host "`n${YELLOW}$Prompt${NC}"
    Write-Host "${BOLD}[y]es / [n]o${NC}: " -NoNewline
    $reply = Read-Host
    return ($reply -match '^y(es)?$')
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
            # Fallback to msg command if on Windows and UI assemblies fail
            if ($IsWindows -ne $false -and (Get-Command msg -ErrorAction SilentlyContinue)) {
                msg * /TIME:10 "📦 System Update Toolkit: $Message" 2>$null
            }
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
$systemDrive = if ($env:SystemDrive) { $env:SystemDrive } else { "C:" }
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
if ($IsWindows -ne $false -and (Get-PSDrive -Name HKLM -ErrorAction SilentlyContinue)) {
    if (Test-Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches" -ErrorAction SilentlyContinue) {
        $keys = Get-ChildItem "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches" -ErrorAction SilentlyContinue
        foreach ($k in $keys) {
            if ($null -ne $k.GetValue("StateFlags0001")) {
                $HasSageSet = $true
                break
            }
        }
    }
}
if (-not $HasSageSet -and $IsWindows -ne $false) {
    Write-Host "${YELLOW}Tip: Disk Cleanup preset 1 has not been configured. Running '/sagerun:1' might skip files.${NC}"
    Write-Host "To configure it, run this command once in an elevated shell: ${CYAN}cleanmgr.exe /sageset:1${NC}"
}
if ($script:IsDryRun) {
    Write-Host "${CYAN}[DRY RUN] Would launch: cleanmgr.exe /sagerun:1${NC}"
} elseif ($IsWindows -ne $false) {
    Write-Host "${YELLOW}This will launch the Disk Cleanup tool. Please select the items you wish to clean.${NC}"
    Start-Process "cleanmgr.exe" -ArgumentList "/sagerun:1" -Wait
} else {
    Write-Host "${YELLOW}Skipping Disk Cleanup (not running on Windows).${NC}"
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
if (Confirm-Destructive -Enabled $ClearHistory.IsPresent -SwitchName "-ClearHistory" -Prompt "Do you want to clear PowerShell history?") {
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

# 7.5. Optional: Docker Cleanup
if (Get-Command docker -ErrorAction SilentlyContinue) {
    if (Confirm-Destructive -Enabled $DockerCleanup.IsPresent -SwitchName "-DockerCleanup" -Prompt "Do you want to run Docker cleanup (dangling images, stopped containers, unused networks/volumes, build cache)?") {
        Write-Host "`n${BLUE}==>${NC} ${BOLD}Cleaning up Docker resources...${NC}"
        if ($script:IsDryRun) {
            Write-Host "${CYAN}[DRY RUN] Would run: docker system prune --volumes -f${NC}"
        } else {
            docker system prune --volumes -f
            if ($LASTEXITCODE -eq 0) {
                Write-Host "${GREEN}Docker resources cleaned up.${NC}"
            } else {
                Write-Host "${RED}Docker cleanup encountered errors.${NC}"
            }
        }
    }
}

# 7.6. Docker container logs (report only)
# Docker Desktop keeps container logs and the daemon config inside its VM, so
# they cannot be measured or truncated from Windows. Instead, report which
# containers run without a log size limit and explain how to set one.
$script:DockerLogSummary = $null
if (Get-Command docker -ErrorAction SilentlyContinue) {
    $previousPreference = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        docker info *> $null
        if ($LASTEXITCODE -eq 0) {
            Write-Host "`n${BLUE}==>${NC} ${BOLD}Checking Docker container logs...${NC}"
            $containerIds = @(docker ps -aq 2>$null | Where-Object { $_ })
            $unlimitedCount = 0
            if ($containerIds.Count -gt 0) {
                $logConfigs = @(docker inspect --format '{{.HostConfig.LogConfig.Type}}|{{index .HostConfig.LogConfig.Config "max-size"}}' @containerIds 2>$null)
                foreach ($logConfig in $logConfigs) {
                    $parts = "$logConfig" -split '\|', 2
                    if ($parts[0] -eq "json-file" -and -not $parts[1]) { $unlimitedCount++ }
                }
            }

            Write-Host "Container logs live inside the Docker Desktop VM; sizes cannot be measured from Windows."
            if ($unlimitedCount -gt 0) {
                Write-Host "${YELLOW}$unlimitedCount of $($containerIds.Count) container(s) have no log size limit and can grow without bound.${NC}"
                Write-Host "To limit them, open Docker Desktop > Settings > Docker Engine, add the following, then Apply & restart:"
                Write-Host "    ${CYAN}`"log-opts`": { `"max-size`": `"50m`", `"max-file`": `"3`" }${NC}"
                Write-Host "Existing containers pick this up once recreated (docker compose up -d --force-recreate)."
                $script:DockerLogSummary = "${YELLOW}$unlimitedCount of $($containerIds.Count) container(s) unlimited${NC}"
            } elseif ($containerIds.Count -gt 0) {
                Write-Host "${GREEN}All containers have a log size limit.${NC}"
                $script:DockerLogSummary = "${GREEN}All containers limited${NC}"
            } else {
                Write-Host "No containers found."
            }
        }
    } finally {
        $ErrorActionPreference = $previousPreference
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
if ($script:DockerLogSummary) {
    Write-Host "Docker log limits : ${BOLD}$($script:DockerLogSummary)"
}
Write-Host "Total Disk Saved  : ${BOLD}${GREEN}$HumanSaved${NC}"
Write-Host "${BOLD}${CYAN}=====================================${NC}"

Write-Host "`n${GREEN}$(Get-Date) - Windows system update completed successfully.${NC}"

# Send desktop notification
Send-Notification "Maintenance Complete! $HumanSaved recovered."

