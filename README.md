# <img src="https://raw.githubusercontent.com/FortAwesome/Font-Awesome/master/svgs/solid/rocket.svg" width="32" height="32"> System Update Utility

[![License](https://img.shields.io/badge/license-MIT-green)](LICENSE)
[![ShellCheck](https://img.shields.io/badge/ShellCheck-Passed-brightgreen)](https://www.shellcheck.net/)
[![Last Commit](https://img.shields.io/github/last-commit/nilesh-gore/system-update-utility-ubuntu-and-macbook)](https://github.com/nilesh-gore/system-update-utility-ubuntu-and-macbook/commits/main)
[![Platform](https://img.shields.io/badge/platform-Linux%20%7C%20macOS%20%7C%20Windows%20%7C%20ChromeOS-lightgrey)](#-features)

> **The ultimate cross-platform maintenance suite.** Automate system updates, purge caches, and recover disk space with a single command on **Linux**, **macOS**, **Windows**, and **ChromeOS**.

---

## 🌟 Why Use This?

Keeping a system updated manually is tedious. This utility bundles the best practices for each OS into a **premium terminal experience**:
- ✅ **Cross-Platform**: One repo to rule them all.
- ✅ **Safe**: Non-destructive cleanup of temporary files and caches.
- ✅ **Informative**: Clear summaries of what was updated and how much space was recovered.
- ✅ **Premium UI**: ANSI color-coded output and interactive prompts.

---

## 🚀 Quick Start

### 🐧 Linux / 🍎 macOS / 💻 ChromeOS
```bash
# Clone the repository
git clone https://github.com/nilesh-gore/system-update-utility-ubuntu-and-macbook.git
cd system-update-utility-ubuntu-and-macbook

# Run the relevant script
chmod +x *_update_util.sh
./brew_update_util.sh  # for macOS
./update_util.sh       # for Ubuntu/Debian
./chromeos_update_util.sh # for ChromeOS
```

### 🪟 Windows
```powershell
# Run in PowerShell
.\win_update_util.ps1
```

---

## 💎 Features

### 🍎 macOS (Homebrew)
- **Smart Updates**: Checks for outdated formulae and casks before initiating upgrades.
- **Cask Support**: Optional **Greedy Mode** for auto-updating casks (Chrome, AnyDesk, etc.).
- **Dependency Management**: Automatically removes unused dependencies (`brew autoremove`).
- **Health Check**: Integrated `brew doctor` and background services monitor.

### 🐧 Linux (Debian/Ubuntu)
- **Full Upgrade**: Refreshes package lists and applies all security/software updates.
- **Deep Cleanup**: Purges APT cache, application caches, and thumbnail directories.
- **Log Rotation**: Vacuums systemd journal logs, retaining only the last 7 days.
- **Snap Support**: Refreshes Snaps and purges disabled/old revisions.

### 🪟 Windows (PowerShell)
- **Winget Integration**: Upgrades all applications managed by the Windows Package Manager.
- **System Maintenance**: WSL kernel updates and native Disk Cleanup (`cleanmgr`) integration.
- **Temp Purge**: Safely removes system and user temporary files.
- **Admin Aware**: Checks for elevated privileges to ensure successful execution.

### 💻 ChromeOS (Crostini)
- **Flatpak Optimizer**: Updates Flatpak apps and purges unused runtimes (essential for GUI apps).
- **Apt Management**: Full Debian-container system updates.
- **Dev Tooling**: Optional global `npm` and `pip` update checks.

---

## 📊 Comparison Matrix

| Feature | 🐧 Linux | 🍎 macOS | 🪟 Windows | 💻 ChromeOS |
| :--- | :---: | :---: | :---: | :---: |
| **Package Update** | `apt` | `brew` | `winget` | `apt` |
| **GUI App Update** | `snap` | `cask` | `winget` | `flatpak` |
| **Cache Cleanup** | ✅ | ✅ | ✅ | ✅ |
| **Health Check** | ✅ | ✅ | ❌ | ✅ |
| **Log Vacuuming** | ✅ | ❌ | ❌ | ✅ |
| **Interactive** | ✅ | ✅ | ✅ | ✅ |

---

## 🛠 Troubleshooting

> [!TIP]
> **Windows**: If you get a script execution error, run: `Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser`

> [!IMPORTANT]
> **macOS**: Ensure Homebrew is in your PATH. If not installed, run: `/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"`

---

## 📁 Logging & Maintenance
- **Logs**: Linux logs are stored in `/var/log/sysupdate.log`. For others, use `./script.sh | tee update.log`.
- **Frequency**: Recommended to run **weekly** to keep your system lean and secure.

---

## 🤝 Contribution
Contributions are what make the open-source community such an amazing place to learn, inspire, and create. Any contributions you make are **greatly appreciated**.

1. Fork the Project
2. Create your Feature Branch (`git checkout -b feature/AmazingFeature`)
3. Commit your Changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the Branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

---

## 📄 License
Distributed under the MIT License. See `LICENSE` for more information.

<p align="center">Made with ❤️ for a cleaner terminal</p>
