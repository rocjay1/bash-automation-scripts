# bash-automation-scripts

A collection of bash scripts for system automation, backup, and auditing.

## backup.sh

Automates the backup of a local source directory to a remote Git repository.

### Features

- Creates a `tar.gz` archive of a specified source directory.
- Clones a remote backup repository if it doesn't exist locally.
- Cleans up old backups in the repository before adding the new one.
- Pushes the new backup to the remote repository.
- Logs activities and errors to a log file.
- Outputs errors to stderr for visibility in cron jobs or CI/CD pipelines.
- Handles concurrent git changes with `git pull --rebase`.

### Configuration

The script uses the following default configuration variables which can be modified in the script:

- `LOG_DIR`: Directory for logs (`${HOME}/log/bash-automation-scripts`).
- `SOURCE_DIR`: The directory to back up (`${HOME}/Source`).
- `REMOTE_REPO`: The remote Git repository URL.
- `BACKUP_DIR`: Temporary directory for the backup repository (`/tmp/bash-automation-scripts-backup`).

### Usage

Ensure you have SSH access configured for the remote repository if using the default SSH URL.

```bash
chmod +x backup.sh
./backup.sh
```

## system_audit.sh

Performs a system security and health audit, generating a report in Markdown format.

### Features

- **Security Audit**: Analyzes `/var/log/auth.log` to report failed SSH login attempts (brute-force detection).
- **Service Pulse**: Checks the status of essential services (`ssh`, `docker`) and verifies internet connectivity (via `google.com`).
- **Resource Sentinel**: Monitors disk usage and alerts on partitions that are more than 80% full.
- **Reporting**: Writes the audit results to `system_audit/AUDIT.md`.

### Usage

Run the script to generate the audit report:

```bash
chmod +x system_audit.sh
./system_audit.sh
```

The output will be saved to: `system_audit/AUDIT.md`