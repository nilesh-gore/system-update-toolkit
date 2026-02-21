# ![System Update Utility](https://img.shields.io/badge/System%20Update-Utility-blue) System Update Utility

[![License](https://img.shields.io/badge/license-MIT-green)](LICENSE)
[![ShellCheck](https://img.shields.io/badge/ShellCheck-Passed-brightgreen)](https://www.shellcheck.net/)
[![Last Commit](https://img.shields.io/github/last-commit/yourusername/system-update-utility)](https://github.com/yourusername/system-update-utility/commits/main)

> 🚀 **Automate system updates and cleanup** for **Debian/Ubuntu Linux** & **macOS**.
> Save time, free disk space, and keep your system optimized—effortlessly.

---

## 🌟 Features

### 🐧 Linux (Debian/Ubuntu)

* Updates package lists & upgrades installed packages
* Fixes broken packages & installs missing dependencies
* Removes unused packages (`autoremove --purge`)
* Cleans APT cache, application caches, & thumbnail caches
* Cleans systemd journal logs (keeps last 7 days)
* Updates Snap packages & removes old revisions
* Displays disk space recovered
* Optional terminal history clearing
* POSIX-compatible (`sh` or `./`)
* Logs output to `/var/log/sysupdate.log`

### 🍎 macOS (Homebrew)

* Updates Homebrew itself
* Upgrades installed formulae & casks
* Cleans up old formulae & cask versions
* Optionally removes Homebrew cache (`~/Library/Caches/Homebrew`)
* Displays disk space freed
* Optional terminal history clearing
* POSIX-compatible (`sh` or `./`)

---

## 🛠 Requirements

| Platform | Requirements                                       | Optional                                            |
| -------- | -------------------------------------------------- | --------------------------------------------------- |
| Linux    | Debian/Ubuntu, sudo, `apt`, `journalctl`, `numfmt` | `snap`, `debsums`                                   |
| macOS    | Homebrew installed, `brew` command                 | `numfmt` (coreutils), `osascript` for notifications |

> ⚠ **Note:** Scripts remove caches & old logs, personal files remain safe.

---

## 📝 Installation & Usage

### Linux

```bash
# Create the script
cd ~/your-project
nano update_util.sh

# Make it executable
chmod +x update_util.sh

# Run
sudo ./update_util.sh
# or POSIX-compatible
sudo sh update_util.sh
```

> Prompts optional terminal history clearing.

### macOS

```bash
# Create the script
cd ~/your-project
nano brew_update_util.sh

# Make it executable
chmod +x brew_update_util.sh

# Run
./brew_update_util.sh
# or POSIX-compatible
sh brew_update_util.sh
```

> Prompts optional Homebrew cache cleanup and terminal history clearing.

---

## 📊 Cleanup Summary

### Linux

| Component                      | Action                         |
| ------------------------------ | ------------------------------ |
| APT Cache                      | Fully cleared                  |
| Unused Packages                | Removed (`autoremove --purge`) |
| Application Cache (`~/.cache`) | Cleared                        |
| Thumbnails                     | Removed                        |
| Journal Logs                   | Older than 7 days removed      |
| Old Snap Revisions             | Removed (if Snap installed)    |

### macOS

| Component                                    | Action                   |
| -------------------------------------------- | ------------------------ |
| Homebrew Formulae                            | Updated & upgraded       |
| Homebrew Casks                               | Updated & upgraded       |
| Old Formulae & Cask Versions                 | Removed (`brew cleanup`) |
| Homebrew Cache (`~/Library/Caches/Homebrew`) | Optionally removed       |
| Terminal History                             | Optionally cleared       |

---

## ⚙️ Troubleshooting

### Linux

* Permissions: `sudo ./update_util.sh`
* Missing utilities: `sudo apt install debsums snapd`
* Snap not installed: skipped automatically

### macOS

* Homebrew not installed:

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

* Missing utilities: `brew install coreutils` for `numfmt`

---

## 📁 Logs

* Linux: `/var/log/sysupdate.log`
* macOS: optional `~/brew_update.log` via `tee`

---

## 🧠 Recommended Usage

* Run weekly or bi-weekly
* Avoid interrupting updates
* Keep only required language versions to save space
* Automate via `cron` (Linux) or `launchd` (macOS)

---

## 💡 Contribution

Contributions welcome! Open issues or pull requests for:

* Bug fixes
* Feature improvements
* New functionality

---

## 📄 License

This project is licensed under the [MIT License](LICENSE).

