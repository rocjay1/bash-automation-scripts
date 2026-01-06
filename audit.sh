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

SERVICES=("ssh" "docker" "google")
DF_THRESH=80
SSH_LOG_FILE="/var/log/auth.log"

# Ensure logging directory exists and
#  add newline to log file
mkdir -p "$LOG_DIR"
echo "" >> "$LOG_FILE"

# Ensure Markdown directory exists and 
#  overwrite any earlier audits 
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

log "Detecting failed logins..."
write_md "## Security Audit"
# https://askubuntu.com/a/178019
# Filter for brute-force interactive SSH logins
FAILED_LOGINS=$(awk '/Failed password for/ { 
        i = match($0, /[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}/)
        m = substr($0, RSTART, RLENGTH)
        a[m]++
    } END {
    for (m in a) { printf("%-15s %s\n", a[m], m) }
}' "$SSH_LOG_FILE" | 
sort -nr | 
head -n 3 | 
# Match start of line OR 1 or more spaces greedily OR end of line 
#  and replace with "|" for Markdown conversion
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
for S in $"${SERVICES[@]}"; do
    case $S in 
        ssh|docker)
            if systemctl is-active --quiet "$S"; then
                STATUS="active"
            else
                STATUS="inactive"
            fi
            write_md "|$S|$STATUS|" 0
        ;;
        google)
            CHECK=$(curl -Is "https://www.$S.com" | head -n 1 || true)
            if [[ "$CHECK" =~ "^HTTP" ]]; then 
                STATUS=$(echo "$CHECK" | sed -n 's/.*\([0-9]\{3\}\).*/\1/p')
            else 
                STATUS="error"
            fi
            write_md "|$S|$STATUS|"
        ;;
    esac
done
log "Finished checking service health."

log "Checking system resources..."
write_md "## Resource Sentinel"
# Need to reference $DF_THRESH, so awk command is nasty
# Wrap in "" and escape nested instances: \"\"
PARTS_STATUS=$(df | awk "NR > 1 { 
    gsub(/%/,\"\",\$5)
    if (\$5 > $DF_THRESH) {
        printf(\"%-15s %s\n\", \$1, \$5)
    }
}" |
sed 's/\(^\)\|\([[:space:]]\+\)\|\($\)/\|/g')

if [[ -z "$PARTS_STATUS" ]]; then
    write_md "All partitions healthy." 0
else
    write_md "CRITICAL partitions (>$DF_THRESH% full):"
    write_md "|PARTITION|PERCENT FULL|\n|---|---|" 0
    write_md "$PARTS_STATUS" 0
fi
log "Finished checking system resources."

log "Finished automated security and pulse audit."
