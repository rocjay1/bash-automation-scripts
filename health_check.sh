#! /bin/bash

# https://askubuntu.com/a/178019
# Filter for brute-force interactive SSH logins
# Look for failed connections (i.e. no login attempted, could be a port scanner, etc.)
awk '/Connection closed by|Failed password/ { 
    where = match($0, /[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}/)
    print substr($0, RSTART, RLENGTH)
}' /var/log/auth.log > >(sort | uniq -c)