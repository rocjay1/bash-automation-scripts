#! /bin/bash

# Strict mode: fail on error, undefined variable, or pipe failure
set -euo pipefail

# Set up log file
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

# TODO: set up Markdown writing


# Main logic
echo -e "# Automated Security & Pulse Audit\n"

echo -e "## Security Audit\n"

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
    echo -e "No failed login attempts."
else
    echo -e "Failed SSH login attempts:\n"
    echo -e "|COUNT|IP|\n|---|---|"
    echo "$FAILED_LOGINS"
fi

echo -e "\n## Service Pulse\n"

echo -e "|SERVICE|STATUS|\n|---|---|"
for s in ssh docker google; do
    case $s in 
        ssh|docker)
            STATUS=$(systemctl status "$s" | sed -n -e 's/^[[:space:]]*Active: \([[:alpha:]]\+ ([[:alpha:]]\+)\).*/\1/p')
            echo "|ssh|$STATUS|"
        ;;
        google)
            STATUS=$(curl -Is "https://www.$s.com" | head -n 1 | sed -n 's/.*\([0-9]\{3\}\).*/\1/p')
            echo "|url|$STATUS|"
        ;;
    esac
done

echo -e "\n## Resource Sentinel\n"

PARTS_STATUS=$(df | awk 'NR > 1 { 
    gsub(/%/,"",$5)
    if ($5 > 80) {
        printf("%-15s %s\n", $1, $5)
    }
}' |
sed 's/\(^\)\|\([[:space:]]\+\)\|\($\)/\|/g')

if [[ -z "$PARTS_STATUS" ]]; then
    echo -e "All partitions healthy.\n"
else
    echo -e "CRITICAL partitions (>80% full):\n"
    echo -e "|PARTITION|PERCENT FULL|\n|---|---|"
    echo "$PARTS_STATUS"
fi
