# System Update Utility

This script automates system maintenance tasks including updating packages, cleaning up cache, and managing system logs. It’s a convenient way to keep your system up-to-date and clean while freeing up disk space.

## Prerequisites

Ensure you have the necessary permissions to run the script and make system modifications (e.g., root or sudo access).

## Script Overview

### Features

* Updates package lists and upgrades installed packages.
* Removes unnecessary packages.
* Clears cached files (APT cache, application caches, and thumbnail cache).
* Clears old journal logs (retains logs from the last 7 days).
* Prompts for clearing terminal history with a timeout.

## How to Use

### 1. **Create the Script**

Navigate to your project directory and create the script file.

```bash
cd ~/your-project
touch update_util.sh
nano update_util.sh
```

### 2. **Add Script Content**

To add the content of the script, simply **copy and paste** the content from the `update_util.sh` file already present in this repository.

```bash
# Open the update_util.sh file from the repository
cat update_util.sh
```

Then, copy the entire script content and paste it into the newly created `update_util.sh` file.

### 3. **Make the Script Executable**

To run the script, make it executable by running the following command:

```bash
chmod +x update_util.sh
```

### 4. **Run the Script**

Now you can run the script using either of the following commands:

```bash
sudo ./update_util.sh
```

or

```bash
bash update_util.sh
```

## Troubleshooting

### Common Issues

* **Permissions**: If you encounter a permissions error, ensure that you have the correct privileges to run the script (`sudo` is often required).
* **Missing Dependencies**: The script assumes some utilities (e.g., `sudo`, `apt`, `journalctl`) are available. Ensure you have the necessary tools installed.

