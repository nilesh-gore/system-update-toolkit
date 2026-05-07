# ![System Update Utility](https://img.shields.io/badge/System%20Update-Utility-blue) System Update Utility

[![License](https://img.shields.io/badge/license-MIT-green)](LICENSE)
[![ShellCheck](https://img.shields.io/badge/ShellCheck-Passed-brightgreen)](https://www.shellcheck.net/)
[![Last Commit](https://img.shields.io/github/last-commit/yourusername/system-update-utility)](https://github.com/yourusername/system-update-utility/commits/main)

> 🚀 **Automate system updates and cleanup** for **Debian/Ubuntu Linux** & **macOS**.
> Save time, free disk space, and keep your system optimized—effortlessly.

---

## 🌟 Features

### 🐧 Linux (Debian/Ubuntu)
*   **Premium Visuals:** ANSI color-coded output.
*   **Maintenance:** Updates package lists, upgrades packages, and fixes broken dependencies.
*   **Deep Cleanup:** Clears APT cache, app caches, and vacuums journal logs.

### 🍎 macOS (Homebrew)
*   **Smart Updates:** Checks for outdated packages before upgrading.
*   **Cask Support:** Optional **Greedy Mode** for auto-updating casks.
-   **Health Check:** Optional `brew doctor` and services check.

### 🪟 Windows (PowerShell)
*   **Winget Integration:** Updates all applications installed via Winget.
*   **System Maintenance:** WSL kernel updates and Disk Cleanup (`cleanmgr`) integration.
*   **Temp Cleanup:** Optional purging of system and user temporary folders.

### 💻 ChromeOS (Crostini)
*   **Linux Container:** Specialized for the ChromeOS Linux environment.
*   **Flatpak Support:** Updates Flatpak apps and removes unused runtimes (essential for ChromeOS GUI apps).
*   **Dev Tools:** Optional global `npm` and `pip` package updates.

---

## 🛠 Requirements

| Platform | Requirements | Optional |
| :--- | :--- | :--- |
| Linux | Debian/Ubuntu, sudo, `apt` | `snap`, `debsums`, `numfmt` |
| macOS | Homebrew, `brew` command | `numfmt` (coreutils) |
| Windows | PowerShell 5.1+, `winget` | Admin privileges |
| ChromeOS | Linux (Crostini) enabled | `flatpak`, `npm`, `pip3` |

---

## 📝 Installation & Usage

### Linux / macOS / ChromeOS
```bash
chmod +x *_update_util.sh
./<script_name>.sh
```

### Windows
```powershell
# Run in PowerShell
.\win_update_util.ps1
```

---

## 📊 Cleanup Summary

| Platform | Core Action | Cleanup Targets |
| :--- | :--- | :--- |
| **Linux** | `apt upgrade` | Cache, Journals, Snaps |
| **macOS** | `brew upgrade` | Caches, Old Versions |
| **Windows** | `winget upgrade` | Temp files, Disk Cleanup |
| **ChromeOS** | `apt` + `flatpak` | Unused runtimes, Cache |

---

## ⚙️ Troubleshooting

### Windows
*   If script execution is disabled, run: `Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser`

### ChromeOS
*   Ensure "Linux development environment" is turned on in Settings.

---

## 📁 Logs
*   Linux: `/var/log/sysupdate.log`
*   macOS/ChromeOS: Manual log via `| tee update.log`

---

## 🧠 Recommended Usage
*   Run weekly or after installing several new applications.
*   Always check the summary to see how much space was recovered.

---

## 💡 Contribution
Contributions welcome! Open issues or pull requests for bug fixes or feature improvements.

---

## 📄 License
This project is licensed under the [MIT License](LICENSE).
