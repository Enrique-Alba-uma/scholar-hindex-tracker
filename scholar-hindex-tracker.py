#!/usr/bin/env python3
"""
scholar-hindex-tracker.py
---------------------------------------------------------------------------
Python port of scholar-hindex-tracker.ps1. Logs your Google Scholar citation
count and h-index, one line per run:

    2026-11-01 09:00 | Citations: 25213 | h-index: 73

Self-contained: edit the three values in "1. Configuration" and run it.
Uses only the Python 3 standard library (no pip install needed).

WHAT YOU NEED (two values, both free to obtain)
  - Your Google Scholar author ID: the value after "user=" in the address
    bar of your Scholar profile.
    Example: https://scholar.google.com/citations?user=AbCdEfGhIjKL
             -> author ID is AbCdEfGhIjKL   (this is NOT your ORCID)
  - A SerpApi key: create a free account at https://serpapi.com and copy
    the "API Key" from your dashboard.

RUN IT BY HAND
    python3 scholar-hindex-tracker.py

RUN IT EVERY DAY
  - Linux/macOS (cron, `crontab -e`):
        0 9 * * * /usr/bin/env python3 /path/to/scholar-hindex-tracker.py
  - Windows: Task Scheduler, program "python", argument the script path.

Original author: Enrique Alba (https://github.com/Enrique-Alba-uma)
License: MIT (see LICENSE)
"""

import json
import os
import ssl
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from datetime import datetime

# 1. Configuration --------------------------------------------------------
SCHOLAR_ID = "PUT_YOUR_SCHOLAR_AUTHOR_ID_HERE"
API_KEY = "PUT_YOUR_SERPAPI_KEY_HERE"  # or set the SERPAPI_KEY environment variable
LOG_NAME = "scholar_history.txt"       # log file, created next to this script

MAX_TRIES = 3


def log(line, log_file):
    print(line)
    with open(log_file, "a", encoding="utf-8") as f:
        f.write(line + "\n")


def ssl_context():
    """Default TLS context; if Python has no CA certificates of its own
    (e.g. python.org builds on macOS), fall back to the system bundle."""
    ctx = ssl.create_default_context()
    if ctx.cert_store_stats()["x509_ca"] == 0:
        for cafile in ("/etc/ssl/cert.pem", "/etc/ssl/certs/ca-certificates.crt"):
            if os.path.exists(cafile):
                ctx.load_verify_locations(cafile)
                break
    return ctx


def fetch(url):
    """Return (citations, h_index) or raise an exception with a message."""
    try:
        with urllib.request.urlopen(url, timeout=15, context=ssl_context()) as resp:
            body = resp.read()
    except urllib.error.HTTPError as e:
        body = e.read()  # SerpApi reports errors in the JSON body
    data = json.loads(body.decode("utf-8"))
    if data.get("error"):
        raise RuntimeError("SerpApi says: {}".format(data["error"]))
    try:
        table = data["cited_by"]["table"]
        return table[0]["citations"]["all"], table[1]["h_index"]["all"]
    except (KeyError, IndexError, TypeError):
        raise RuntimeError(
            "SerpApi did not return the expected data. Check your author ID and API key."
        )


def main():
    # 2. Checks -----------------------------------------------------------
    api_key = API_KEY
    if api_key.startswith("PUT_YOUR_") and os.environ.get("SERPAPI_KEY"):
        api_key = os.environ["SERPAPI_KEY"]
    if SCHOLAR_ID.startswith("PUT_YOUR_") or api_key.startswith("PUT_YOUR_"):
        print("Edit the '1. Configuration' section of this script: "
              "set your Scholar author ID and your SerpApi key.")
        return 1

    script_dir = os.path.dirname(os.path.abspath(__file__))
    log_file = os.path.join(script_dir, LOG_NAME)
    url = "https://serpapi.com/search.json?" + urllib.parse.urlencode({
        "engine": "google_scholar_author",
        "author_id": SCHOLAR_ID,
        "api_key": api_key,
    })
    date = datetime.now().strftime("%Y-%m-%d %H:%M")

    # 3. Query with retries (network errors are common) -------------------
    for attempt in range(1, MAX_TRIES + 1):
        try:
            citations, h_index = fetch(url)
            log("{} | Citations: {} | h-index: {}".format(date, citations, h_index), log_file)
            return 0
        except Exception as e:
            if attempt < MAX_TRIES:
                time.sleep(10)
            else:
                log("{} | ERROR after {} attempts: {}".format(date, MAX_TRIES, e), log_file)
                return 2


if __name__ == "__main__":
    sys.exit(main())
