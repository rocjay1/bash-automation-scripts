#! /bin/bash

# Strict mode
set -euo pipefail

write_md() {
    local line="$1" 
    local empty_lines="${2:-1}"
    local file="${3:-AUDIT.md}"

    i=0
    while [[ $i -lt $empty_lines ]]; do
        line="$line\n"
        ((i++))
    done
    echo -e "$line" >> "$file"
}

write_md "# Automated Security & Pulse Audit"

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
    write_md "|COUNT|IP|\n|---|---|"
    write_md "$FAILED_LOGINS"
fi

write_md "## Service Pulse"

write_md "|SERVICE|STATUS|\n|---|---|"
for s in ssh docker google; do
    case $s in 
        ssh|docker)
            STATUS=$(systemctl status "$s" | sed -n -e 's/^[[:space:]]*Active: \([[:alpha:]]\+ ([[:alpha:]]\+)\).*/\1/p')
            write_md "|ssh|$STATUS|" 0
        ;;
        google)
            STATUS=$(curl -Is "https://www.$s.com" | head -n 1 | sed -n 's/.*\([0-9]\{3\}\).*/\1/p')
            write_md "|url|$STATUS|"
        ;;
    esac
done

write_md "## Resource Sentinel"

PARTS_STATUS=$(df | awk 'NR > 1 { 
    gsub(/%/,"",$5)
    if ($5 > 80) {
        printf("%-15s %s\n", $1, $5)
    }
}' |
sed 's/\(^\)\|\([[:space:]]\+\)\|\($\)/\|/g')

if [[ -z "$PARTS_STATUS" ]]; then
    write_md "All partitions healthy."
else
    write_md "CRITICAL partitions (>80% full):"
    write_md "|PARTITION|PERCENT FULL|\n|---|---|"
    write_md "$PARTS_STATUS"
fi
