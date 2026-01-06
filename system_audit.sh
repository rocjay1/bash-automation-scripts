#! /bin/bash

# Strict mode: fail on error, undefined variable, or pipe failure
set -euo pipefail

# Set up logging
LOG_DIR="${HOME}/log/bash-automation-scripts"
LOG_FILE="$LOG_DIR/health_check.log"
if [ ! -d "$LOG_DIR" ]; then
    mkdir -p "$LOG_DIR"
fi
if [ ! -f "$LOG_FILE" ]; then
    touch "$LOG_FILE"
fi

# Redirect stderr to log file
exec 2>> "$LOG_FILE" 

# Set up Markdown output
MARKDOWN_DIR="."
MARKDOWN_FILE="$MARKDOWN_DIR/AUDIT.md"
if [ ! -d "$MARKDOWN_DIR" ]; then
    mkdir -p "$MARKDOWN_DIR"
fi
if [ ! -f "$MARKDOWN_FILE" ]; then
    touch "$MARKDOWN_FILE"
else
    echo -n "" > "$MARKDOWN_FILE"
fi

write() {
    local line=$1
    local file=${2-"AUDIT.md"}
    echo -e "$line\n" >> "$file"
}

# Main logic
write "# Automated Security & Pulse Audit"

write "## Security Audit"

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
    write "No failed login attempts."
else
    write "Failed SSH login attempts:"
    write "|COUNT|IP|\n|---|---|"
    write "$FAILED_LOGINS"
fi

write "## Service Pulse"

write "|SERVICE|STATUS|\n|---|---|"
for s in ssh docker google; do
    case $s in 
        ssh|docker)
            STATUS=$(systemctl status "$s" | sed -n -e 's/^[[:space:]]*Active: \([[:alpha:]]\+ ([[:alpha:]]\+)\).*/\1/p')
            write "|ssh|$STATUS|"
        ;;
        google)
            STATUS=$(curl -Is "https://www.$s.com" | head -n 1 | sed -n 's/.*\([0-9]\{3\}\).*/\1/p')
            write "|url|$STATUS|"
        ;;
    esac
done

write "## Resource Sentinel"

PARTS_STATUS=$(df | awk 'NR > 1 { 
    gsub(/%/,"",$5)
    if ($5 > 80) {
        printf("%-15s %s\n", $1, $5)
    }
}' |
sed 's/\(^\)\|\([[:space:]]\+\)\|\($\)/\|/g')

if [[ -z "$PARTS_STATUS" ]]; then
    write "All partitions healthy."
else
    write "CRITICAL partitions (>80% full):"
    write "|PARTITION|PERCENT FULL|\n|---|---|"
    write "$PARTS_STATUS"
fi
