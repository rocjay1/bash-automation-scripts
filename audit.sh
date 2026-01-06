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

# Configuration
LOG_DIR="/var/log/bash-automation-scripts"

# Ensure logging directory exists
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/audit.log"
echo "" >> "$LOG_FILE"

log() {
    local message="$1"
    local log_entry="[$(date -Iseconds)] $message"
    echo "$log_entry" >> "$LOG_FILE"
}

# Redirect stdout and stderr to log file
exec 1>> "$LOG_FILE" 2>&1

# Markdown
MARKDOWN_DIR="/var/temp/audit"
mkdir -p "$MARKDOWN_DIR"
MARKDOWN_FILE="$MARKDOWN_DIR/AUDIT_$(date -Idate).md"
touch "$MARKDOWN_FILE"

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

# Main
log "Starting automated security and pulse audit..."
write_md "# Automated Security & Pulse Audit"
write_md "## Security Audit"

log "Parsing SSH logs to detect failed logins..."
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
for s in ssh docker google; do
    case $s in 
        ssh|docker)
            STATUS=$(systemctl status "$s" | sed -n -e 's/^[[:space:]]*Active: \([[:alpha:]]\+ ([[:alpha:]]\+)\).*/\1/p')
            write_md "|$s|$STATUS|" 0
        ;;
        google)
            STATUS=$(curl -Is "https://www.$s.com" | head -n 1 | sed -n 's/.*\([0-9]\{3\}\).*/\1/p')
            write_md "|$s|$STATUS|"
        ;;
    esac
done
log "Finished checking service health."

log "Checking system resources..."
write_md "## Resource Sentinel"
PARTS_STATUS=$(df | awk 'NR > 1 { 
    gsub(/%/,"",$5)
    if ($5 > 80) {
        printf("%-15s %s\n", $1, $5)
    }
}' |
sed 's/\(^\)\|\([[:space:]]\+\)\|\($\)/\|/g')

if [[ -z "$PARTS_STATUS" ]]; then
    write_md "All partitions healthy." 0
else
    write_md "CRITICAL partitions (>80% full):"
    write_md "|PARTITION|PERCENT FULL|\n|---|---|" 0
    write_md "$PARTS_STATUS" 0
fi
log "Finished checking system resources."
