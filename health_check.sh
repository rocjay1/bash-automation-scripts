#! /bin/bash

# Set up logging

# Security Audit
echo -e "|COUNT|IP|\n|---|---|"

# https://askubuntu.com/a/178019
# Filter for brute-force interactive SSH logins
# Look for failed connections (i.e. no login attempted, could be a port scanner, etc.)
awk '/Connection closed by|Failed password for/ { 
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
sed 's/\(^\)\|\([[:space:]]\+\)\|\($\)/\|/g'