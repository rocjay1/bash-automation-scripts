#! /bin/bash

# ==============================================================================
# Script: audit.sh
# Description: Automates security and system health auditing.
#              Generates a Markdown report and logs activities.
#
# Checks:
#   - Failed SSH login attempts (brute-force detection)
#   - Status of critical services (ssh, docker) and connectivity (google)
#   - Disk usage (alerts if >80%)
#
# Output:
#   - Log: /var/log/bash-automation-scripts/audit.log
#   - Report: /var/temp/audit/AUDIT_<Date>.md
# ==============================================================================

# Enable strict error handling
set -euo pipefail

# ==============================================================================
# Configuration
# ==============================================================================

LOG_DIR="/var/log/bash-automation-scripts"
LOG_FILE="$LOG_DIR/audit.log"
MARKDOWN_DIR="/var/tmp/audit"
MARKDOWN_FILE="$MARKDOWN_DIR/AUDIT_$(date -Idate).md"

STATUS_CHECKS=("ssh" "docker" "google")
DU_THRESH=80

# Ensure logging directory exists and
# add newline to log file
mkdir -p "$LOG_DIR"
echo "" >> "$LOG_FILE"

# Ensure Markdown directory exists and 
# overwrite any earlier audits 
mkdir -p "$MARKDOWN_DIR"
echo "" > "$MARKDOWN_FILE"

# Functions
log() {
    local message="$1"
    local log_entry="[$(date -Iseconds)] $message"
    echo "$log_entry" >> "$LOG_FILE"
}

write_md() {
    local line="$1" 
    local empty_lines="${2:-1}"
    local file="${3:-$MARKDOWN_FILE}"

    i=0
    while [[ $i -lt $empty_lines ]]; do
        line="$line\n"
        ((++i))
    done
    echo -e "$line" >> "$file"
}

# ==============================================================================
# Main Execution
# ==============================================================================

# Redirect stdout and stderr to log file
exec 1>> "$LOG_FILE" 2>&1

log "Starting automated security and pulse audit..."

write_md "# Automated Security & Pulse Audit"

log "Parsing SSH logs to detect failed logins..."
write_md "## Security Audit"
# https://askubuntu.com/a/178019
# Filter for brute-force interactive SSH logins
FAILED_LOGINS=$(awk '/Failed password for/ { 
        i = match($0, /[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}/)
        m = substr($0, RSTART, RLENGTH)
        a[m]++
    } END {
    for (m in a) {
        printf("%-15s %s\n", a[m], m)
    }
}' /var/log/auth.log | 
sort -nr | 
head -n 3 | 
# Match start of line OR 1 or more spaces OR end of line 
# and replace with "|"
sed 's/\(^\)\|\([[:space:]]\+\)\|\($\)/\|/g')

if [[ -z "$FAILED_LOGINS" ]]; then
    write_md "No failed login attempts."
else
    write_md "Failed SSH login attempts:"
    write_md "|COUNT|IP|\n|---|---|" 0
    write_md "$FAILED_LOGINS"
fi
log "Finished detecting failed logins."


log "Checking service health..."
write_md "## Service Pulse"
write_md "|SERVICE|STATUS|\n|---|---|" 0
for s in $"${STATUS_CHECKS[@]}"; do
    case $s in 
        ssh|docker)
            if systemctl is-active --quiet "$s"; then
                STATUS="active"
            else
                STATUS="inactive"
            fi
            write_md "|$s|$STATUS|" 0
        ;;
        google)
            STATUS=$(curl -Is "https://www.$s.com" | head -n 1 | sed -n 's/.*\([0-9]\{3\}\).*/\1/p' || true)
            write_md "|$s|$STATUS|"
        ;;
    esac
done
log "Finished checking service health."

log "Checking system resources..."
write_md "## Resource Sentinel"
PARTS_STATUS=$(df | awk "NR > 1 { 
    gsub(/%/,\"\",\$5)
    if (\$5 > $DU_THRESH) {
        printf(\"%-15s %s\n\", \$1, \$5)
    }
}" |
sed 's/\(^\)\|\([[:space:]]\+\)\|\($\)/\|/g')

if [[ -z "$PARTS_STATUS" ]]; then
    write_md "All partitions healthy." 0
else
    write_md "CRITICAL partitions (>$DU_THRESH% full):"
    write_md "|PARTITION|PERCENT FULL|\n|---|---|" 0
    write_md "$PARTS_STATUS" 0
fi
log "Finished checking system resources."

log "Finished automated security and pulse audit."
