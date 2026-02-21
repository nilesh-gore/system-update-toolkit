# ![System Update Utility](https://img.shields.io/badge/System%20Update-Utility-blue) System Update Utility

[![License](https://img.shields.io/badge/license-MIT-green)](LICENSE)
[![ShellCheck](https://img.shields.io/badge/ShellCheck-Passed-brightgreen)](https://www.shellcheck.net/)
[![Last Commit](https://img.shields.io/github/last-commit/yourusername/system-update-utility)](https://github.com/yourusername/system-update-utility/commits/main)

> Automated system maintenance script for Debian/Ubuntu-based systems.
> Keeps your system updated, cleans cache, manages journal logs, and frees disk space.

---

## 🚀 Features

* Updates package lists and upgrades installed packages
* Fixes broken packages and installs missing dependencies
* Removes unused packages (`autoremove --purge`)
* Cleans APT cache and system/application caches
* Removes old thumbnail files
* Cleans systemd journal logs (keeps last 7 days)
* Updates Snap packages (if installed) and removes old revisions
* Displays a cleanup summary (disk space recovered)
* Optional terminal history clearing
* POSIX-compatible: works with both `sh` and `./` execution
* Logs output to `/var/log/sysupdate.log`

---

## 🛠 Requirements

* Debian/Ubuntu-based Linux
* `sudo` privileges
* Required commands: `apt`, `journalctl`, `numfmt`
* Optional: `snap`, `debsums`

> ⚠ **Note:** The script will remove cached files and old logs. Personal files remain untouched.

---

## 📝 Installation & Usage

### 1️⃣ Clone or Create the Script

```bash
cd ~/your-project
nano update_util.sh
```

Paste the script content into the file.

---

### 2️⃣ Make It Executable

```bash
chmod +x update_util.sh
```

---

### 3️⃣ Run the Script

Recommended:

```bash
sudo ./update_util.sh
```

POSIX-compatible:

```bash
sudo sh update_util.sh
```

> The script will prompt whether to clear terminal history (optional).

---

## 📊 What Gets Cleaned

| Component                      | Action                         |
| ------------------------------ | ------------------------------ |
| APT Cache                      | Fully cleared                  |
| Unused Packages                | Removed (`autoremove --purge`) |
| Application Cache (`~/.cache`) | Cleared                        |
| Thumbnails                     | Removed                        |
| Journal Logs                   | Older than 7 days removed      |
| Old Snap Revisions             | Removed (if Snap is installed) |

---

## ⚙️ Troubleshooting

### Permission Errors

Ensure you run the script with `sudo`:

```bash
sudo ./update_util.sh
```

### Missing Utilities

Install missing dependencies:

```bash
sudo apt install debsums snapd
```

### Snap Not Installed

The Snap update/cleanup steps are skipped automatically if Snap is not installed.

---

## 📁 Log File

Execution results are logged at:

```bash
/var/log/sysupdate.log
```

---

## 🧠 Recommended Usage

* Run weekly or bi-weekly
* Avoid interrupting during package upgrades
* Reboot if kernel updates were applied
* Keep only required Python or other versions to save space

---

## 💡 Contribution

Contributions are welcome! Please open issues or pull requests for bug fixes, improvements, or feature requests.

---

## 📄 License

This project is licensed under the [MIT License](LICENSE).

