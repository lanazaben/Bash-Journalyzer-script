 #!/bin/bash
# ===========================
# Journalyzer - Offline Log Extractor & Analyzer (Style B)
# ===========================

conf="journalyzer.conf"

# ===========================
# Step 0: Validate input
# ===========================
if [ $# -ne 1 ]; then
    echo "Usage: offline.sh <journal_file>"
    exit 1
fi

journal_file="$1"

if [ ! -f "$journal_file" ]; then
    echo "ERROR: Journal file not found: $journal_file"
    exit 1
fi

# ===========================
# Step 1: Load configuration
# ===========================
if [ ! -f "$conf" ]; then
    echo "ERROR: Configuration file not found at $conf"
    exit 1
fi

#bash timeRange.sh "$journal_file"

time_range=$(grep -i "^time_range" "$conf" | cut -d "=" -f 2- | tr -d '"' | xargs)
error_keywords=$(grep -i "^ERROR:" "$conf" | cut -d ":" -f2- | tr -d ' ' | tr ',' ' ')
warning_keywords=$(grep -i "^WARNING:" "$conf" | cut -d ":" -f2- | tr -d ' ' | tr ',' ' ')

#echo "Time range read from conf: '$time_range'"

# Time flags
if [ -z "$time_range" ]; then
    time_flag=""
    time_value=""
else
    time_flag="--since"
    time_value="$time_range"
fi

error_pattern=$(echo "$error_keywords" | sed 's/ /|/g')
warning_pattern=$(echo "$warning_keywords" | sed 's/ /|/g')

IFS=',' read -ra keyword_array <<< "$keywords"

# ===========================
# Step 2: Extract services
# ===========================
if [ ! -x "./serviceImport.sh" ]; then
    echo "ERROR: serviceImport.sh missing or not executable."
    exit 1
fi

echo "Extracting services..."
bash ./serviceImport.sh "$journal_file" "$time_flag" "$time_value"

if [ ! -s temp.txt ]; then
    echo "ERROR: No services found in temp.txt"
    exit 1
fi

# ===========================
# Step 3: Prepare output directory
# ===========================
base_dir="$(dirname "$journal_file")"
output_dir="${base_dir}/offline_logs_styleB"
mkdir -p "$output_dir"

master_service_list="${output_dir}/all_services.txt"
touch "$master_service_list"

cat temp.txt >> "$master_service_list"
sort -u "$master_service_list" -o "$master_service_list"

summary_file="${output_dir}/global_summary.txt"


# ===========================
# Step 4: Per-service log extraction and reports (NO SUMMARY)
# ===========================
echo "Processing per-service logs ..."

while read -r service; do
    [ -z "$service" ] && continue

    safe=$(echo "$service" | tr '/' '_' | tr -d '[:space:]')
    service_dir="${output_dir}/${safe}"
    mkdir -p "$service_dir"

    log_file="${service_dir}/${safe}.log"
    err_file="${service_dir}/errors.log"
    warn_file="${service_dir}/warnings.log"
    normal_file="${service_dir}/normal.log"
    both_file="${service_dir}/both.log"
    report_file="${service_dir}/${safe}_report.txt"

    echo "→ Extracting logs for: $service"

    journalctl --file="$journal_file" | grep -i "$service" >> "$log_file"

    # -----------------------------------------
    # 1. JSON-level “warn” wins (fast grep)
    # -----------------------------------------
    grep -i '"level":"warn"' "$log_file" >> "$warn_file"

    # -----------------------------------------
    # 2. JSON-level “error” next, exclude warn
    # -----------------------------------------
    grep -i '"level":"error"' "$log_file" \
        | grep -iv '"level":"warn"' >> "$err_file"

    # -----------------------------------------
    # 3. Warning keywords (only lines not already classified)
    # -----------------------------------------
    grep -iEv '"level":"warn"|\"level\":\"error\"' "$log_file" \
        | grep -iE "$warning_pattern" >> "$warn_file"

    # -----------------------------------------
    # 4. Error keywords (only lines not already classified)
    # -----------------------------------------
    grep -iEv '"level":"warn"' "$log_file" \
        | grep -iv '"level":"error"' \
        | grep -iE "$error_pattern" >> "$err_file"

    # -----------------------------------------
    # 5. Remaining lines are NORMAL logs
    # -----------------------------------------
    grep -iEv "\"level\":\"warn\"|\"level\":\"error\"|$warning_pattern|$error_pattern" \
        "$log_file" >> "$normal_file"

    # Combined for convenience
    sort "$err_file" "$warn_file" >> "$both_file"

    # BUILD REPORT
    total=$(wc -l < "$log_file")
    ec=$(wc -l < "$err_file")
    wc=$(wc -l < "$warn_file")
    nc=$(wc -l < "$normal_file")

    first_ts=$(head -1 "$log_file" | awk '{print $1, $2, $3}')
    last_ts=$(tail -1 "$log_file" | awk '{print $1, $2, $3}')

    {
        echo " Service Report - $service"
        echo "----------------------------------------------"
        echo "Total entries    : $total"
        echo "Errors           : $ec"
        echo "Warnings         : $wc"
        echo "Normal logs      : $nc"
        echo "First entry      : ${first_ts:-N/A}"
        echo "Last entry       : ${last_ts:-N/A}"
        echo
        echo "=== ERROR LOGS ==="
        cat "$err_file"
        echo
        echo "=== WARNING LOGS ==="
        cat "$warn_file"
        echo
        echo "=== NORMAL LOGS ==="
        cat "$normal_file"
        echo
    } > "$report_file"

done < "$master_service_list"

echo "Building final global summary..."

{
    echo " Journalyzer Offline Summary (Merged Across Journals)"
    echo "======================================================"
    echo
} > "$summary_file"

while read -r service; do
    [ -z "$service" ] && continue

    safe=$(echo "$service" | tr '/' '_' | tr -d '[:space:]')
    service_dir="${output_dir}/${safe}"

    log_file="${service_dir}/${safe}.log"
    err_file="${service_dir}/errors.log"
    warn_file="${service_dir}/warnings.log"

    total=$(wc -l < "$log_file")
    ec=$(wc -l < "$err_file")
    wc=$(wc -l < "$warn_file")

    {
        echo "Service: $service"
        echo "  Entries : $total"
        echo "  Errors  : $ec"
        echo "  Warnings: $wc"
        echo
    } >> "$summary_file"

done < "$master_service_list"

echo "Offline extraction & analysis complete."
echo "Final summary created at: $summary_file"
echo "All outputs stored in: $output_dir"
