#!/usr/bin/env bash
#
#  scholar-hindex-tracker.sh
#  ---------------------------------------------------------------------------
#  Bash port of scholar-hindex-tracker.ps1. Logs your Google Scholar citation
#  count and h-index, one line per run:
#
#      2026-11-01 09:00 | Citations: 25213 | h-index: 73
#
#  Self-contained: edit the three values in "1. Configuration" and run it.
#  Requires only bash and curl. If jq is installed it is used to read the
#  JSON; otherwise a grep/sed fallback is used.
#
#  WHAT YOU NEED (two values, both free to obtain)
#    - Your Google Scholar author ID: the value after "user=" in the address
#      bar of your Scholar profile.
#      Example: https://scholar.google.com/citations?user=AbCdEfGhIjKL
#               -> author ID is AbCdEfGhIjKL   (this is NOT your ORCID)
#    - A SerpApi key: create a free account at https://serpapi.com and copy
#      the "API Key" from your dashboard.
#
#  RUN IT BY HAND
#      chmod +x scholar-hindex-tracker.sh
#      ./scholar-hindex-tracker.sh
#
#  RUN IT EVERY DAY (cron, Linux/macOS) - run `crontab -e` and add:
#      0 9 * * * /path/to/scholar-hindex-tracker.sh >/dev/null 2>&1
#    cron skips runs while the computer is off or asleep. On macOS, a
#    launchd agent with StartCalendarInterval runs a missed job on wake;
#    on Linux, anacron or a systemd timer with Persistent=true does the same.
#
#  Original author: Enrique Alba (https://github.com/Enrique-Alba-uma)
#  License: MIT (see LICENSE)

# 1. Configuration --------------------------------------------------------
SCHOLAR_ID="PUT_YOUR_SCHOLAR_AUTHOR_ID_HERE"
API_KEY="PUT_YOUR_SERPAPI_KEY_HERE"     # or set the SERPAPI_KEY environment variable
LOG_NAME="scholar_history.txt"          # log file, created next to this script

# 2. Checks ---------------------------------------------------------------
case "$API_KEY" in PUT_YOUR_*) [ -n "$SERPAPI_KEY" ] && API_KEY="$SERPAPI_KEY" ;; esac
case "$SCHOLAR_ID$API_KEY" in *PUT_YOUR_*)
    echo "Edit the '1. Configuration' section of this script: set your Scholar author ID and your SerpApi key."
    exit 1 ;;
esac
command -v curl >/dev/null 2>&1 || { echo "curl is required."; exit 1; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="$SCRIPT_DIR/$LOG_NAME"
DATE="$(date '+%Y-%m-%d %H:%M')"

# Extract fields from the JSON response ($1). Prints "citations hindex"
# or "ERROR <message>".
parse() {
    if command -v jq >/dev/null 2>&1; then
        printf '%s' "$1" | jq -r '
            if .error then "ERROR SerpApi says: \(.error)"
            else "\(.cited_by.table[0].citations.all // "") \(.cited_by.table[1].h_index.all // "")"
            end' 2>/dev/null || echo "ERROR Invalid JSON response"
    else
        local flat err c h
        flat="$(printf '%s' "$1" | tr -d '\n\r')"
        err="$(printf '%s' "$flat" | sed -n 's/.*"error"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')"
        if [ -n "$err" ]; then echo "ERROR SerpApi says: $err"; return; fi
        c="$(printf '%s' "$flat" | grep -o '"citations"[[:space:]]*:[[:space:]]*{[[:space:]]*"all"[[:space:]]*:[[:space:]]*[0-9]*' | head -1 | grep -o '[0-9]*$')"
        h="$(printf '%s' "$flat" | grep -o '"h_index"[[:space:]]*:[[:space:]]*{[[:space:]]*"all"[[:space:]]*:[[:space:]]*[0-9]*' | head -1 | grep -o '[0-9]*$')"
        echo "$c $h"
    fi
}

# 3. Query with retries (network errors are common) -----------------------
MAX_TRIES=3
for try in $(seq 1 $MAX_TRIES); do
    # Without --fail, curl also returns the JSON body of HTTP errors
    # (SerpApi puts its error message there); stderr only carries
    # network-level failures.
    if response="$(curl -sS --max-time 15 -G "https://serpapi.com/search.json" \
            --data-urlencode "engine=google_scholar_author" \
            --data-urlencode "author_id=$SCHOLAR_ID" \
            --data-urlencode "api_key=$API_KEY" 2>&1)"; then
        result="$(parse "$response")"
    else
        result="ERROR $(printf '%s' "$response" | tr -d '\n')"
    fi

    case "$result" in
        ERROR*) msg="${result#ERROR }" ;;
        *)
            citations="${result%% *}"; h_index="${result#* }"
            if [ -n "$citations" ] && [ -n "$h_index" ]; then
                line="$DATE | Citations: $citations | h-index: $h_index"
                echo "$line"
                echo "$line" >> "$LOG_FILE"
                exit 0
            fi
            msg="SerpApi did not return the expected data. Check your author ID and API key." ;;
    esac

    if [ "$try" -lt "$MAX_TRIES" ]; then
        sleep 10
    else
        line="$DATE | ERROR after $MAX_TRIES attempts: $msg"
        echo "$line"
        echo "$line" >> "$LOG_FILE"
        exit 2
    fi
done
