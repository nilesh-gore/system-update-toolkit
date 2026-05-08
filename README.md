# 🚀 System Update Utility — Cross-Platform Maintenance Suite

<div align="center">

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![ShellCheck](https://img.shields.io/badge/ShellCheck-Passed-brightgreen?logo=gnu-bash)](https://www.shellcheck.net/)
[![Platform](https://img.shields.io/badge/Platform-Linux%20%7C%20macOS%20%7C%20Windows%20%7C%20ChromeOS-blue)](#-supported-platforms)
[![Maintenance](https://img.shields.io/badge/Maintained%3F-yes-green.svg)](https://github.com/nilesh-gore/system-update-utility-ubuntu-and-macbook/graphs/commit-activity)
[![GitHub last commit](https://img.shields.io/github/last-commit/nilesh-gore/system-update-utility-ubuntu-and-macbook)](https://github.com/nilesh-gore/system-update-utility-ubuntu-and-macbook/commits/main)
[![GitHub stars](https://img.shields.io/github/stars/nilesh-gore/system-update-utility-ubuntu-and-macbook?style=social)](https://github.com/nilesh-gore/system-update-utility-ubuntu-and-macbook/stargazers)
[![GitHub forks](https://img.shields.io/github/forks/nilesh-gore/system-update-utility-ubuntu-and-macbook?style=social)](https://github.com/nilesh-gore/system-update-utility-ubuntu-and-macbook/network/members)

**The ultimate open-source system maintenance toolkit.**
Automate OS updates, purge caches, recover disk space, and keep your dev environment pristine — all from a single terminal command.

<img src="assets/terminal_preview.png" alt="System Update Utility Terminal Preview" width="700">

*Premium color-coded terminal output with interactive cleanup summary*

</div>

---

## 📖 Table of Contents

- [About](#-about)
- [Supported Platforms](#-supported-platforms)
- [Features at a Glance](#-features-at-a-glance)
- [Quick Start](#-quick-start)
- [Detailed Script Breakdown](#-detailed-script-breakdown)
- [Comparison Matrix](#-comparison-matrix)
- [Requirements](#-requirements)
- [Screenshots & Terminal Output](#-screenshots--terminal-output)
- [Troubleshooting](#-troubleshooting)
- [Automation & Scheduling](#-automation--scheduling)
- [FAQ](#-frequently-asked-questions)
- [Contributing](#-contributing)
- [License](#-license)

---

## 📌 About

**System Update Utility** is a collection of lightweight, interactive shell scripts designed to automate the tedious process of keeping your operating system, packages, and development tools up to date.

Whether you're a developer maintaining multiple machines, a sysadmin managing servers, or a power user who wants a clean system — this toolkit has you covered.

### 🎯 Key Benefits

| Benefit | Description |
| :--- | :--- |
| ⏱️ **Time Saver** | One command replaces 10+ manual steps |
| 🧹 **Disk Recovery** | Automatically cleans caches, old versions, and temp files |
| 🛡️ **Safe & Non-destructive** | Only removes system caches and temporary data — your files are never touched |
| 🎨 **Premium Terminal UI** | Beautiful ANSI color-coded output with progress indicators |
| 🔄 **Interactive Prompts** | Choose what to clean — nothing runs without your confirmation |
| 📊 **Cleanup Summary** | See exactly how much disk space was recovered |

---

## 🖥️ Supported Platforms

<table>
<tr>
<td align="center"><b>🐧 Linux</b><br>Ubuntu / Debian<br><code>update_util.sh</code></td>
<td align="center"><b>🍎 macOS</b><br>Homebrew<br><code>brew_update_util.sh</code></td>
<td align="center"><b>🪟 Windows</b><br>PowerShell + Winget<br><code>win_update_util.ps1</code></td>
<td align="center"><b>💻 ChromeOS</b><br>Crostini (Linux)<br><code>chromeos_update_util.sh</code></td>
</tr>
</table>

---

## ✨ Features at a Glance

### 🍎 macOS — `brew_update_util.sh`
- ✅ Updates Homebrew definitions (`brew update`)
- ✅ Smart detection of outdated formulae and casks before upgrading
- ✅ Optional **Greedy Mode** for casks that auto-update (Chrome, Slack, VS Code, etc.)
- ✅ Removes unused dependencies (`brew autoremove`)
- ✅ Runs `brew cleanup` to purge old versions
- ✅ Optional cache purge (`~/Library/Caches/Homebrew`)
- ✅ Integrated `brew doctor` health check
- ✅ Detects and displays running Homebrew background services
- ✅ Interactive terminal history clearing (supports both Zsh and Bash)
- ✅ Human-readable disk space recovery summary
- ✅ **Yes to All** mode: type `a` at any prompt to auto-approve all remaining prompts

### 🐧 Linux — `update_util.sh`
- ✅ Full system update (`apt-get update` + `full-upgrade`)
- ✅ Fixes broken packages and installs missing dependencies
- ✅ Deep cleanup: APT cache, app caches (`~/.cache`), and thumbnail directories
- ✅ Systemd journal log rotation (keeps only last 7 days)
- ✅ Snap package refresh and old revision removal
- ✅ Package integrity verification via `debsums`
- ✅ System file consistency check (`apt-get check`)
- ✅ Logs all operations to `/var/log/sysupdate.log`
- ✅ Human-readable cleanup summary with before/after comparison
- ✅ **Yes to All** mode: type `a` at any prompt to auto-approve all remaining prompts

### 🪟 Windows — `win_update_util.ps1`
- ✅ Lists and upgrades all apps via **Winget** (Windows Package Manager)
- ✅ Optional `--include-unknown` flag for comprehensive upgrades
- ✅ WSL kernel update (`wsl --update`)
- ✅ Native Disk Cleanup tool integration (`cleanmgr`)
- ✅ Purges system and user `%TEMP%` directories
- ✅ Clears PowerShell command history and PSReadLine history
- ✅ Admin privilege detection with warnings
- ✅ Windows Store app update reminder
- ✅ **Yes to All** mode: type `a` at any prompt to auto-approve all remaining prompts

### 💻 ChromeOS — `chromeos_update_util.sh`
- ✅ Full Debian container update (`apt-get update` + `full-upgrade`)
- ✅ Flatpak app updates and unused runtime removal
- ✅ APT cache cleanup (`autoremove` + `autoclean`)
- ✅ Optional global NPM package updates
- ✅ Optional Python pip upgrade and outdated package listing
- ✅ Interactive terminal history clearing
- ✅ **Yes to All** mode: type `a` at any prompt to auto-approve all remaining prompts

---

## 🚀 Quick Start

### Step 1: Clone the Repository
```bash
git clone https://github.com/nilesh-gore/system-update-utility-ubuntu-and-macbook.git
cd system-update-utility-ubuntu-and-macbook
```

### Step 2: Run the Script for Your OS

<details>
<summary><b>🍎 macOS</b></summary>

```bash
chmod +x brew_update_util.sh
./brew_update_util.sh
# or
sh brew_update_util.sh
```
</details>

<details>
<summary><b>🐧 Linux (Ubuntu/Debian)</b></summary>

```bash
chmod +x update_util.sh
sudo ./update_util.sh
# or
sudo sh update_util.sh
```
</details>

<details>
<summary><b>🪟 Windows</b></summary>

```powershell
# Open PowerShell as Administrator (recommended)
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
.\win_update_util.ps1
```
</details>

<details>
<summary><b>💻 ChromeOS</b></summary>

```bash
# Open the Linux terminal from your ChromeOS app drawer
chmod +x chromeos_update_util.sh
./chromeos_update_util.sh
```
</details>

---

## 🔍 Detailed Script Breakdown

### macOS: `brew_update_util.sh`
```
Step 1  →  Update Homebrew definitions
Step 2  →  Detect outdated formulae & casks
Step 3  →  Upgrade formulae (if any outdated)
Step 4  →  Upgrade casks (with optional Greedy Mode)
Step 5  →  Remove unused dependencies (autoremove)
Step 6  →  Cleanup old versions (brew cleanup -s)
Step 7  →  Optional: Purge Homebrew cache
Step 8  →  Check running services
Step 9  →  Optional: Run brew doctor
Step 10 →  Display cleanup summary
Step 11 →  Optional: Clear terminal history
```

### Linux: `update_util.sh`
```
Step 1  →  Capture disk usage (before)
Step 2  →  Update package lists
Step 3  →  Full system upgrade
Step 4  →  Fix broken packages & missing deps
Step 5  →  Remove unused packages (autoremove --purge)
Step 6  →  Clean APT cache, app caches, thumbnails
Step 7  →  Vacuum journal logs (7-day retention)
Step 8  →  Refresh Snap packages & remove old revisions
Step 9  →  Verify package integrity (debsums)
Step 10 →  Capture disk usage (after) & display summary
Step 11 →  Optional: Clear terminal history
Step 12 →  Log to /var/log/sysupdate.log
```

### Windows: `win_update_util.ps1`
```
Step 1  →  Check for Administrator privileges
Step 2  →  List outdated Winget packages
Step 3  →  Optional: Upgrade all Winget packages
Step 4  →  Update WSL kernel
Step 5  →  Launch Disk Cleanup (cleanmgr)
Step 6  →  Optional: Clear temp directories
Step 7  →  Optional: Clear PowerShell history
```

### ChromeOS: `chromeos_update_util.sh`
```
Step 1  →  Update Debian package definitions
Step 2  →  Full system upgrade
Step 3  →  Update Flatpak apps & remove unused runtimes
Step 4  →  Clean APT cache (autoremove + autoclean)
Step 5  →  Optional: Update global NPM packages
Step 6  →  Optional: Update pip & list outdated packages
Step 7  →  Display cleanup summary
Step 8  →  Optional: Clear terminal history
```

---

## 📊 Comparison Matrix

| Feature | 🐧 Linux | 🍎 macOS | 🪟 Windows | 💻 ChromeOS |
| :--- | :---: | :---: | :---: | :---: |
| **Package Manager** | `apt` | `brew` | `winget` | `apt` |
| **GUI App Updates** | `snap` | `cask` | `winget` | `flatpak` |
| **System Upgrade** | ✅ | ✅ | ✅ | ✅ |
| **Cache Cleanup** | ✅ | ✅ | ✅ | ✅ |
| **Disk Space Recovery** | ✅ | ✅ | ✅ | ✅ |
| **Health Check** | `debsums` | `brew doctor` | — | `apt-get check` |
| **Log Vacuuming** | ✅ (journald) | — | — | — |
| **Service Monitor** | — | ✅ | — | — |
| **Dev Tool Updates** | — | — | — | `npm` / `pip` |
| **History Clearing** | ✅ | ✅ | ✅ | ✅ |
| **Color-coded Output** | ✅ | ✅ | ✅ | ✅ |
| **Interactive Prompts** | ✅ | ✅ | ✅ | ✅ |
| **POSIX Compatible** | ✅ | ✅ | — | ✅ |
| **Yes to All (`a`)** | ✅ | ✅ | ✅ | ✅ |

---

## 🛠 Requirements

| Platform | Required | Optional |
| :--- | :--- | :--- |
| **Linux** | Ubuntu/Debian 18.04+, `sudo`, `apt`, `journalctl` | `snap`, `debsums`, `numfmt` (coreutils) |
| **macOS** | macOS 12+, [Homebrew](https://brew.sh) | — |
| **Windows** | Windows 10/11, PowerShell 5.1+, [Winget](https://github.com/microsoft/winget-cli) | Administrator privileges for full cleanup |
| **ChromeOS** | Linux (Crostini) enabled in Settings | `flatpak`, `npm`, `pip3` |

---

## 📸 Screenshots & Terminal Output

### macOS — Homebrew Update
```
**************************************************
*        Homebrew System Update Utility          *
**************************************************

==> Updating Homebrew definitions...
==> Updating Homebrew...
Already up-to-date.
Found 3 outdated formulae and 1 outdated casks.

==> Upgrading installed formulae...
🍺  python@3.12/3.12.13_2: 3,606 files, 70.2MB
🍺  gradle/9.5.0: 11,459 files, 193.6MB

==> Removing unused dependencies (autoremove)...

========== CLEANUP SUMMARY ==========
Homebrew cache cleared: 245.30 MB
=====================================

Thu May  7 18:05:11 IST 2026 - Homebrew system update completed successfully.
```

### Linux — APT Update
```
**************************************************
*        Linux System Update Utility             *
**************************************************

==> Updating system package definitions...
==> Upgrading installed packages...
==> Removing unnecessary packages...
==> Cleaning systemd journal logs (keeping last 7 days)...

========== CLEANUP SUMMARY ==========
APT cache cleared     : 1.2G
App cache cleared     : 450M
Journal cleared       : 120M
=====================================
```

---

## ⚙️ Troubleshooting

<details>
<summary><b>🪟 Windows: Script execution is disabled</b></summary>

```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```
This allows locally-created scripts to run while still blocking unsigned remote scripts.
</details>

<details>
<summary><b>🍎 macOS: Homebrew not found</b></summary>

Install Homebrew first:
```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```
Then add it to your PATH as instructed by the installer.
</details>

<details>
<summary><b>🐧 Linux: Permission denied</b></summary>

Always run the Linux script with `sudo`:
```bash
sudo ./update_util.sh
```
</details>

<details>
<summary><b>💻 ChromeOS: Linux terminal not available</b></summary>

Go to **Settings → Advanced → Developers → Linux development environment** and turn it on. ChromeOS will set up a Debian container automatically.
</details>

<details>
<summary><b>🐧 Linux: debsums not installed</b></summary>

```bash
sudo apt install debsums
```
This enables package integrity verification. The script will skip this step if not installed.
</details>

---

## ⏰ Automation & Scheduling

### 🐧 Linux — Cron Job
```bash
# Edit crontab
crontab -e

# Run every Sunday at 3 AM
0 3 * * 0 /path/to/update_util.sh >> /var/log/sysupdate.log 2>&1
```

### 🍎 macOS — launchd
```bash
# Create a plist in ~/Library/LaunchAgents/
# Or use a simple cron:
crontab -e
0 3 * * 0 /path/to/brew_update_util.sh >> ~/brew_update.log 2>&1
```

### 🪟 Windows — Task Scheduler
```powershell
# Open Task Scheduler → Create Basic Task
# Trigger: Weekly
# Action: Start a Program
# Program: powershell.exe
# Arguments: -File "C:\path\to\win_update_util.ps1"
```

---

## ❓ Frequently Asked Questions

<details>
<summary><b>Will this delete my personal files?</b></summary>

**No.** The scripts only clean system-managed caches, temporary files, old package versions, and log files. Your documents, projects, and personal data are never touched.
</details>

<details>
<summary><b>Can I run this on a server?</b></summary>

**Yes.** The Linux script (`update_util.sh`) works great on headless servers. All interactive prompts can be bypassed by piping input: `echo "y" | sudo ./update_util.sh`
</details>

<details>
<summary><b>How much disk space can I expect to recover?</b></summary>

It varies by system. Typical results:
- **macOS**: 200MB – 2GB (old Homebrew versions and cache)
- **Linux**: 500MB – 5GB (APT cache, journal logs, old Snaps)
- **Windows**: 1GB – 10GB (temp files, Disk Cleanup)
</details>

<details>
<summary><b>Is it safe to run frequently?</b></summary>

**Absolutely.** Running weekly is recommended. If everything is already up to date, the scripts complete in seconds with no changes.
</details>

<details>
<summary><b>Does it support Arch, Fedora, or other Linux distros?</b></summary>

Currently, only **Debian/Ubuntu-based** distros are supported (using `apt`). Support for `dnf` (Fedora) and `pacman` (Arch) is planned for future releases. Contributions welcome!
</details>

---

## 🤝 Contributing

Contributions are what make the open-source community such an amazing place to learn, inspire, and create. Any contributions you make are **greatly appreciated**.

1. **Fork** the Project
2. **Create** your Feature Branch (`git checkout -b feature/AmazingFeature`)
3. **Commit** your Changes (`git commit -m 'feat: add AmazingFeature'`)
4. **Push** to the Branch (`git push origin feature/AmazingFeature`)
5. **Open** a Pull Request

### 💡 Ideas for Contributions
- Add support for Fedora (`dnf`) and Arch Linux (`pacman`)
- Create a unified wrapper script that auto-detects the OS
- Add Chocolatey support for Windows alongside Winget
- Add notification support (desktop notifications on completion)

---

## 📝 Changelog

| Version | Date | Changes |
| :--- | :--- | :--- |
| **v2.1** | 2026-05-08 | Added `a` (yes to all) interactive option across all prompts, `--help`/`--version` flags, made Linux cache wipes interactive, added disk stats & `apt-get check` to ChromeOS, added cleanup summary to Windows, fixed README inaccuracies, added LICENSE file |
| **v2.0** | 2026-05-07 | Added Windows & ChromeOS support, premium ANSI visuals, `brew doctor`, `autoremove`, greedy cask upgrades, comparison matrix |
| **v1.0** | Initial | Linux (`apt`) and macOS (`brew`) update utilities |

---

## ⭐ Star History

If this project helped you, please consider giving it a ⭐ — it helps others discover it!

---

## 📄 License

Distributed under the **MIT License**. See [`LICENSE`](LICENSE) for more information.

---

<div align="center">

**Made with ❤️ by [Nilesh Gore](https://github.com/nilesh-gore)**

*Keep your systems clean. Keep your terminal beautiful.*

[⬆ Back to Top](#-system-update-utility--cross-platform-maintenance-suite)

</div>
