# ![System Update Utility](https://img.shields.io/badge/System%20Update-Utility-blue) System Update Utility

[![License](https://img.shields.io/badge/license-MIT-green)](LICENSE)
[![ShellCheck](https://img.shields.io/badge/ShellCheck-Passed-brightgreen)](https://www.shellcheck.net/)
[![Last Commit](https://img.shields.io/github/last-commit/yourusername/system-update-utility)](https://github.com/yourusername/system-update-utility/commits/main)

> Automated system maintenance scripts for **Debian/Ubuntu Linux** and **macOS**.
> Keep your system updated, clean, and optimized while freeing disk space.

---

## 🚀 Features

### Linux (Debian/Ubuntu)

* Updates package lists and upgrades installed packages
* Fixes broken packages and installs missing dependencies
* Removes unused packages (`autoremove --purge`)
* Cleans APT cache, application caches, and thumbnail caches
* Cleans systemd journal logs (retains last 7 days)
* Updates Snap packages (if installed) and removes old revisions
* Displays a cleanup summary (disk space recovered)
* Optional terminal history clearing
* POSIX-compatible: works with both `sh` and `./` execution
* Logs output to `/var/log/sysupdate.log`

### macOS (Homebrew)

* Updates Homebrew itself
* Upgrades installed formulae and casks
* Cleans up old formulae and cask versions
* Optionally removes old cached downloads from `~/Library/Caches/Homebrew`
* Displays a cleanup summary (disk space freed)
* Optional terminal history clearing
* POSIX-compatible: works with both `sh` and `./` execution

---

## 🛠 Requirements

### Linux

* Debian/Ubuntu-based system
* `sudo` privileges
* Required commands: `apt`, `journalctl`, `numfmt`
* Optional: `snap`, `debsums`

### macOS

* macOS with Homebrew installed
* `brew` command available
* Optional: `numfmt` (coreutils)
* Optional: `osascript` for notifications

> ⚠ **Note:** Both scripts remove caches and old logs. Personal files remain untouched.

---

## 📝 Installation & Usage

### Linux

1. Create the script:

```bash
cd ~/your-project
nano update_util.sh
```

2. Paste the Linux script content and save.
3. Make it executable:

```bash
chmod +x update_util.sh
```

4. Run the script:

```bash
sudo ./update_util.sh
```

POSIX-compatible:

```bash
sudo sh update_util.sh
```

> The script prompts whether to clear terminal history (optional).

### macOS

1. Create the script:

```bash
cd ~/your-project
nano brew_update_util.sh
```

2. Paste the macOS script content and save.
3. Make it executable:

```bash
chmod +x brew_update_util.sh
```

4. Run the script:

```bash
./brew_update_util.sh
```

POSIX-compatible:

```bash
sh brew_update_util.sh
```

> The script prompts whether to remove Homebrew caches and optionally clear terminal history.

---

## 📊 Cleanup Summary Tables

### Linux

| Component                      | Action                         |
| ------------------------------ | ------------------------------ |
| APT Cache                      | Fully cleared                  |
| Unused Packages                | Removed (`autoremove --purge`) |
| Application Cache (`~/.cache`) | Cleared                        |
| Thumbnails                     | Removed                        |
| Journal Logs                   | Older than 7 days removed      |
| Old Snap Revisions             | Removed (if Snap is installed) |

### macOS (Homebrew)

| Component                                    | Action                   |
| -------------------------------------------- | ------------------------ |
| Homebrew Formulae                            | Updated and upgraded     |
| Homebrew Casks                               | Updated and upgraded     |
| Old Formulae & Cask Versions                 | Removed (`brew cleanup`) |
| Homebrew Cache (`~/Library/Caches/Homebrew`) | Optionally removed       |
| Terminal History                             | Optionally cleared       |

---

## ⚙️ Troubleshooting

### Linux

* **Permissions:** Use `sudo ./update_util.sh`
* **Missing utilities:** Install `debsums` or `snapd`:

```bash
sudo apt install debsums snapd
```

* **Snap not installed:** Snap steps are skipped automatically.

### macOS

* **Homebrew not installed:** Install via:

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

* **Permissions:** Homebrew usually does not require `sudo`. Ensure your user has write access.
* **Missing utilities:** Install `coreutils` for `numfmt`:

```bash
brew install coreutils
```

---

## 📁 Logs

* Linux: `/var/log/sysupdate.log`
* macOS: Optional `~/brew_update.log` via `tee`

---

## 🧠 Recommended Usage

* Run weekly or bi-weekly
* Avoid interrupting during updates
* Keep only required Python or other versions to save space
* Optional: automate via `cron` (Linux) or `launchd` (macOS)

---

## 💡 Contribution

Contributions welcome! Open issues or pull requests for bug fixes, improvements, or new features.

---

## 📄 License

This project is licensed under the [MIT License](LICENSE).

