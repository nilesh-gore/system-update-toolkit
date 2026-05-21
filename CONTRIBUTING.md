# 🤝 Contributing to System Update Toolkit

First off, **thank you** for considering contributing! Every contribution helps make this toolkit better for everyone.

## 📋 Table of Contents

- [Code of Conduct](#-code-of-conduct)
- [How Can I Contribute?](#-how-can-i-contribute)
- [Getting Started](#-getting-started)
- [Development Guidelines](#-development-guidelines)
- [Submitting Changes](#-submitting-changes)
- [Style Guide](#-style-guide)

---

## 📜 Code of Conduct

This project follows a simple rule: **be kind and respectful**. We're all here to build something useful together.

---

## 💡 How Can I Contribute?

### 🐛 Report Bugs
- Use the [Bug Report](https://github.com/nilesh-gore/system-update-toolkit/issues/new?template=bug_report.md) issue template
- Include your OS version, shell version, and steps to reproduce

### ✨ Suggest Features
- Use the [Feature Request](https://github.com/nilesh-gore/system-update-toolkit/issues/new?template=feature_request.md) issue template
- Describe the problem your feature would solve

### 🔧 Submit Code
Here are some ideas:
- **Add support for Arch Linux** (`pacman` package manager) and **OpenSUSE** (`zypper` package manager)
- **Add Chocolatey support** for Windows alongside Winget
- **Add Docker cleanup logic** (dangling images/volumes)
- **Implement a "Doctor" health check** for Windows/Linux/Fedora
- **Improve error handling** and edge cases
- **Add unit tests** for script functions

---

## 🚀 Getting Started

1. **Fork** the repository
2. **Clone** your fork:
   ```bash
   git clone https://github.com/YOUR_USERNAME/system-update-toolkit.git
   cd system-update-toolkit
   ```
3. **Create** a feature branch:
   ```bash
   git checkout -b feature/your-feature-name
   ```
4. **Make** your changes
5. **Test** on your platform
6. **Commit** and **push**

---

## 📐 Development Guidelines

### Shell Scripts (`.sh`)

- **POSIX compliance**: Prefer POSIX-compatible syntax where possible
- **ShellCheck**: All scripts must pass [ShellCheck](https://www.shellcheck.net/) with no errors
  ```bash
  shellcheck your_script.sh
  ```
- **Interactive prompts**: Use the shared `ask_user()` function pattern for consistency
- **Colors**: Use the established ANSI color variables (`GREEN`, `CYAN`, `YELLOW`, `RED`, `NC`)
- **Error handling**: Always check if commands exist before running them

### PowerShell Scripts (`.ps1`)

- Follow existing patterns in `win_update_util.ps1`
- Use ANSI escape codes for colored output (matching the patterns in `win_update_util.ps1`)
- Check for admin privileges where needed

### General

- Keep scripts **lightweight** — no external dependencies
- Every cleanup action should be **interactive** (confirm before destructive operations)
- Include a **cleanup summary** with disk space recovered
- Support the **"Yes to All" (`a`)** prompt pattern

---

## 📤 Submitting Changes

1. **Commit** with a clear message following [Conventional Commits](https://www.conventionalcommits.org/):
   ```
   feat: add Fedora (dnf) support
   fix: handle missing brew command gracefully
   docs: update comparison matrix for new platform
   ```

2. **Push** to your fork:
   ```bash
   git push origin feature/your-feature-name
   ```

3. **Open a Pull Request** against `main` with:
   - A clear description of what changed
   - The platform(s) you tested on
   - Screenshots of terminal output (if applicable)

---

## 🎨 Style Guide

### Naming
- Script files: `lowercase_with_underscores.sh`
- Functions: `snake_case()`
- Variables: `UPPER_CASE` for constants, `lower_case` for locals

### Script Structure
```bash
#!/bin/bash
# ============================================
# Script Name: your_script.sh
# Description: Brief description
# Platform:    Target OS
# ============================================

# --- Color Definitions ---
# --- Helper Functions ---
# --- Main Logic ---
# --- Cleanup Summary ---
```

### Terminal Output
- Use `===>` prefix for major steps
- Use `✅` for success, `⚠️` for warnings, `❌` for errors
- Always show a cleanup summary at the end

---

## ❓ Questions?

Feel free to [open an issue](https://github.com/nilesh-gore/system-update-toolkit/issues) or start a [discussion](https://github.com/nilesh-gore/system-update-toolkit/discussions).

**Thank you for contributing! 🙏**
