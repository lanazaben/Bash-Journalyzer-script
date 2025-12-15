#!/bin/bash
# ================================================
# Journalyzer - Extract Time Range From Offline Journal
# ================================================

conf="/etc/journalyzer.conf"

if [ $# -ne 1 ]; then
    echo "Usage: extract_time_range.sh <services.journal>"
    exit 1
fi

journal_file="$1"

if [ ! -f "$journal_file" ]; then
    echo "ERROR: Journal file not found: $journal_file"
    exit 1
fi

echo "Extracting timestamps from $journal_file ..."
echo

# Extract timestamps using journalctl metadata
timestamps=$(journalctl --file="$journal_file" --output=short --no-pager | \
    awk '{print $1, $2, $3}' | \
    grep -E "^[A-Z][a-z]{2} [ 0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}$")

if [ -z "$timestamps" ]; then
    echo "ERROR: No timestamps extracted — journal format may be unusual."
    exit 1
fi

# Sort timestamps chronologically
earliest=$(echo "$timestamps" | sort | head -1)
latest=$(echo "$timestamps" | sort | tail -1)

echo "Earliest timestamp: $earliest"
echo "Latest timestamp:   $latest"
echo

# Convert into a usable date in system format: "YYYY-MM-DD HH:MM:SS"
earliest_sys=$(date -d "$earliest" +"%Y-%m-%d %H:%M:%S" 2>/dev/null)
latest_sys=$(date -d "$latest" +"%Y-%m-%d %H:%M:%S" 2>/dev/null)

echo "Earliest (system format): $earliest_sys"
echo "Latest   (system format): $latest_sys"
echo

# ================================
# Update time range in the config
# ================================
if [ -f "$conf" ]; then
    echo "Updating $conf ..."
  sudo  sed -i "s/^TIME_RANGE=.*/TIME_RANGE=\"$earliest_sys\"/" "$conf"
    echo "TIME_RANGE updated to: $earliest_sys"
else
    echo "WARNING: Config not found at $conf — skipping update."
fi

echo
echo "Done."

