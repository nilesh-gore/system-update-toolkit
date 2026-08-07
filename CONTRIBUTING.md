# 🤝 Contributing to System Update Toolkit

First off, **thank you** for considering contributing! 🎉

Whether you're fixing a typo, reporting a bug, improving documentation, or adding a major feature, your contribution is greatly appreciated. Every contribution helps make **System Update Toolkit** better for everyone.

---

# 📋 Table of Contents

- [Code of Conduct](#-code-of-conduct)
- [Supported Platforms](#-supported-platforms)
- [Development Requirements](#-development-requirements)
- [Repository Layout](#-repository-layout)
- [Ways to Contribute](#-ways-to-contribute)
- [Getting Started](#-getting-started)
- [Development Guidelines](#-development-guidelines)
- [Testing Checklist](#-testing-checklist)
- [Coding Standards](#-coding-standards)
- [Security Guidelines](#-security-guidelines)
- [Performance Guidelines](#-performance-guidelines)
- [Pull Request Process](#-pull-request-process)
- [Branch Naming](#-branch-naming)
- [Commit Message Guidelines](#-commit-message-guidelines)
- [Continuous Integration](#-continuous-integration)
- [Documentation Standards](#-documentation-standards)
- [Style Guide](#-style-guide)
- [License](#-license)
- [Recognition](#-recognition)
- [Questions](#-questions)

---

# 📜 Code of Conduct

This project follows one simple rule:

> **Be respectful, welcoming, and constructive.**

Please:

- Be polite
- Respect different opinions
- Give constructive feedback
- Help newcomers
- Keep discussions professional

Harassment, discrimination, or abusive behavior will not be tolerated.

---

# 💻 Supported Platforms

| Platform | Package Manager | Status |
|-----------|-----------------|--------|
| Ubuntu | APT | ✅ Stable |
| Debian | APT | ✅ Stable |
| Linux Mint | APT | ✅ Stable |
| Pop!_OS | APT | ✅ Stable |
| Fedora | DNF | ✅ Stable |
| RHEL / AlmaLinux / Rocky | DNF | ✅ Stable |
| ChromeOS (Crostini) | APT | ✅ Stable |
| macOS | Homebrew | ✅ Stable |
| Windows | Winget | ✅ Stable |
| Arch Linux | Pacman | 🚧 Planned |
| OpenSUSE | Zypper | 🚧 Planned |

---

# 🛠 Development Requirements

Recommended tools:

- Git
- ShellCheck
- PowerShell 7+
- Bash or POSIX-compatible shell
- GitHub CLI (optional)

Verify installation:

```bash
git --version
shellcheck --version
pwsh --version

📁 Repository Layout
system-update-toolkit/
├── toolkit.sh
├── update_util.sh
├── fedora_update_util.sh
├── chromeos_update_util.sh
├── brew_update_util.sh
├── win_update_util.ps1
├── README.md
├── CONTRIBUTING.md
├── CHANGELOG.md
├── LICENSE
├── docs/
├── assets/
└── .github/

💡 Ways to Contribute
🐛 Report Bugs

Before opening an issue:

Search existing issues
Test on the latest release
Include your OS version
Include shell version
Include terminal output
Provide steps to reproduce
Include screenshots when appropriate
✨ Suggest Features

Feature requests should include:

Problem description
Proposed solution
Expected behavior
Possible implementation ideas
🔧 Submit Code

Examples:

Add Arch Linux support
Add OpenSUSE support
Add Chocolatey support
Add Scoop support
Docker cleanup
Podman cleanup
Health Check ("Doctor") mode
Better logging
Performance improvements
Error handling improvements
Documentation updates
Unit tests
CI improvements
🚀 Getting Started
1. Fork the repository

Click Fork on GitHub.

2. Clone
git clone https://github.com/YOUR_USERNAME/system-update-toolkit.git
cd system-update-toolkit

3. Create a branch
git checkout -b feature/my-feature

4. Make your changes

Keep commits focused and easy to review.

5. Test
./toolkit.sh --dry-run


Run ShellCheck:

shellcheck *.sh

6. Commit
git commit -m "feat: add Arch Linux support"

7. Push
git push origin feature/my-feature

8. Open a Pull Request

Include:

Description
Tested platforms
Screenshots (if applicable)
Related issues
📐 Development Guidelines
Shell Scripts
Prefer POSIX syntax
Pass ShellCheck with no errors
Quote variables
Use printf instead of echo for formatted output
Prefer command -v
Avoid eval
Handle errors gracefully
Reuse helper functions
PowerShell
Follow existing coding style
Use approved verbs
Check administrator privileges
Handle exceptions properly
General
Keep scripts lightweight
Avoid unnecessary dependencies
Support Dry Run mode
Confirm destructive operations
Keep output user-friendly
Maintain backward compatibility
✅ Testing Checklist

Before opening a Pull Request:

 No syntax errors
 ShellCheck passes
 Help command works
 Version command works
 Dry Run works
 Interactive prompts work
 Cleanup summary appears
 Exit codes are correct
 Documentation updated
🔢 Exit Codes
Code	Meaning
0	Success
1	General Error
2	Invalid Arguments
126	Permission Denied
127	Command Not Found
🔒 Security Guidelines

Please avoid:

Hardcoded passwords
API keys
Access tokens
Secrets
Credentials
Unsafe eval
Blind recursive deletion

Always validate user input before execution.

⚡ Performance Guidelines

Please:

Minimize external command usage
Avoid unnecessary subprocesses
Reuse helper functions
Keep startup fast
Reduce unnecessary disk access
📤 Pull Request Process

Before requesting review:

 Code tested
 Documentation updated
 CHANGELOG updated (if applicable)
 No merge conflicts
 CI passes
 Conventional Commits used
🌿 Branch Naming

Examples:

feature/add-arch-support
feature/docker-cleanup
fix/flatpak-update
fix/cache-cleanup
docs/readme-update
docs/contributing-update
refactor/wrapper
test/add-shell-tests
ci/github-actions

📝 Commit Message Guidelines

This project follows Conventional Commits.

Examples:

feat: add Fedora support
feat: add Docker cleanup
fix: handle missing brew gracefully
fix: prevent Flatpak update failure
docs: improve installation guide
docs: update screenshots
refactor: simplify wrapper detection
test: add ShellCheck workflow
ci: add GitHub Actions
style: format shell scripts

🤖 Continuous Integration

Pull Requests should pass:

ShellCheck
PowerShell syntax validation
Markdown lint
YAML validation
GitHub Actions workflows

Please resolve CI failures before requesting review.

📚 Documentation Standards

If your contribution changes functionality, update:

README.md
CHANGELOG.md
Screenshots (if applicable)
Usage examples
Command documentation

Documentation improvements are always welcome.

🎨 Style Guide
Naming

Files

update_util.sh
chromeos_update_util.sh
fedora_update_util.sh


Functions

snake_case()


Variables

UPPER_CASE
lower_case

Terminal Output

Use:

==> for major steps
✅ Success
⚠️ Warning
❌ Error
ℹ️ Information

Always display a cleanup summary.

📄 License

By contributing to this project, you agree that your contributions will be licensed under the MIT License.

❤️ Recognition

Every contribution matters.

Whether you:

Report a bug
Fix a typo
Improve documentation
Add a feature
Review Pull Requests
Improve performance
Help other users

you are helping make System Update Toolkit better for everyone.

Thank you! 🎉

❓ Questions?

Need help?

Open a GitHub Issue
Start a GitHub Discussion
Review the project documentation

Happy coding! 🚀

:::

This is ready to save directly as **`CONTRIBUTING.md`** in your repository.
