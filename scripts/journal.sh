# Journalyzer - Keyword Analysis

conf="journalyzer.conf"

# Configuration Validation
if [ ! -f "$conf" ]; then
    echo "ERROR: Configuration file $conf not found."
    exit 1
fi

# --- READ CONFIG VALUES ---
ONLINE_TIME=$(grep -i "^ONLINE_TIME" "$conf" | cut -d "=" -f2 | xargs)
threshold=$(grep -i "^ALERT_THRESHOLD" "$conf" | cut -d "=" -f2 | tr -d ' ')
offlineDirectory=$(grep -i "^DIRECTORY" "$conf" | cut -d "=" -f2 | xargs)

# --- FIX: Auto-generate ONLINE_TIME (epoch - 72h) if empty ---
if [[ -z "$ONLINE_TIME" ]]; then
    ONLINE_TIME=$(date -d "72 hours ago" +%s)
    sed -i "s/^ONLINE_TIME=.*/ONLINE_TIME=$ONLINE_TIME/" "$conf"
fi

# Mode Selection
echo "Select mode:"
echo "1) Online  - Fetch logs using journalctl"
echo "2) Offline - Use local .journal files"
read -p "Enter choice (1 or 2): " mode

# OFFLINE MODE
if [ -d "../offline_logs_styleB" ] ; then
	sudo rm -r ../offline_logs_styleB
	echo "directory deleted"
fi
if [ "$mode" = "2" ]; then
    if [ ! -d "$offlineDirectory" ]; then
        echo "ERROR: Directory '$offlineDirectory' not found."
        exit 1
    fi

    echo "Offline mode activated — scanning: $offlineDirectory"
    shopt -s nullglob

    for file in "$offlineDirectory"/*.journal; do
        echo "Processing offline journal: $(basename "$file")"
        bash offline2.sh "$file"
    done

    exit 0
fi

# ONLINE MODE
online_raw="onlineJournal.txt"
online_services="dynamic_services.txt"

journalctl --no-pager > "$online_raw"

awk '
{
    svc=$5
    gsub(/\[.*\]/,"",svc)   # remove [PID]
    gsub(/:/,"",svc)        # remove trailing :
    if (svc ~ /^[a-zA-Z0-9_.-]+$/)
        print svc
}
' "$online_raw" | sort -u > "$online_services"

if [ ! -s "$online_services" ]; then
    echo "No services discovered in online logs."
    exit 0
fi

echo "→ Discovered $(wc -l < "$online_services") unique services."
echo
# Phase 1: Extract service logs
while read -r s; do
    [ -z "$s" ] && continue
    log_output="../$s.log"

    echo "Processing service: $s"

    if systemctl list-units --all --type=service | grep -q "^$s\.service"; then
        journalctl -u "$s"  --no-pager > "$log_output"
    else
        unit=$(systemctl list-units --all | awk '{print $1}' | grep -i "^$s" | head -1)
        if [ -n "$unit" ]; then
            journalctl -u "$unit" --no-pager > "$log_output"
        else
            journalctl  --no-pager | grep -i " $s" > "$log_output"
        fi
    fi

    # ❌ REMOVE EMPTY LOG FILES
    if [ ! -s "$log_output" ]; then
        rm -f "$log_output"
    fi

done < "$online_services"


# READ KEYWORDS
keywords_raw=""
err_vals=$(grep -i "^ERROR:" "$conf" | cut -d ":" -f2- | tr ',' ' ' | xargs)
warn_vals=$(grep -i "^WARNING:" "$conf" | cut -d ":" -f2- | tr ',' ' ' | xargs)
keywords_raw="$err_vals $warn_vals"

keyword_list=()
for k in $keywords_raw; do
    k_trimmed=$(echo "$k" | xargs)
    if [ -n "$k_trimmed" ]; then
        keyword_list+=("$k_trimmed")
    fi
done

if [ ${#keyword_list[@]} -eq 0 ]; then
    echo "WARNING: No keywords found."
fi

# Phase 2: Keyword Analysis
csv_report="../keyword_analysis.csv"
echo "No.,Service,Keyword,Count" > "$csv_report"

printf "\n%-5s %-22s %-22s %-10s\n" "No." "Service" "Keyword" "Count"
printf "%-5s %-22s %-22s %-10s\n" "----" "----------------------" "----------------------" "----------"

serial=1
total_count=0

while read -r s; do
    log_file="../$s.log"
    [ ! -s "$log_file" ] && continue

    for key in "${keyword_list[@]}"; do
        count=$(grep -i -F -c "$key" "$log_file" 2>/dev/null)
        printf "%-5s %-22s %-22s %-10s\n" "$serial" "$s" "$key" "$count"
        echo "$serial,$s,$key,$count" >> "$csv_report"
        serial=$((serial + 1))
        total_count=$((total_count + count))
    done
done < "$online_services"

# Alert Check
echo
echo "Total occurrences: $total_count"
echo "Alert threshold: $threshold"
echo "CSV saved: $csv_report"

if [ "$total_count" -gt "$threshold" ]; then
    echo "ALERT: Threshold exceeded!"
fi

# Phase 4: Summary Report
summary_file="../summary-$(date +%F).txt"
echo " Journalyzer Summary Report - $(date)" > "$summary_file"
echo "==========================================" >> "$summary_file"
echo >> "$summary_file"

while read -r s; do
    log_file="../$s.log"
    [ ! -f "$log_file" ] && continue

    echo "Service: $s" >> "$summary_file"
    echo "------------------------------------------" >> "$summary_file"

    total_entries=$(wc -l < "$log_file")
    first_ts=$(head -1 "$log_file")
    last_ts=$(tail -1 "$log_file")
    peak_hour=$(awk '{print $3}' "$log_file" | cut -d: -f1 | sort | uniq -c | sort -nr | head -1 | awk '{print $2}')

    echo "Total entries: $total_entries" >> "$summary_file"
    echo "First entry: $first_ts" >> "$summary_file"
    echo "Last entry:  $last_ts" >> "$summary_file"
    echo "Peak hour: ${peak_hour:-N/A}" >> "$summary_file"

    echo "Keyword counts:" >> "$summary_file"
    for key in "${keyword_list[@]}"; do
        kcount=$(grep -i -c "$key" "$log_file")
        echo "   $key : $kcount" >> "$summary_file"
    done

    echo >> "$summary_file"

    # Store error logs in separate file
    error_log_file="../${s}.errors.log"
    grep -iE "error|fail|failed|critical|alert" "$log_file" > "$error_log_file" || echo "No error entries found." > "$error_log_file"

    echo "Error Log Entries saved to: $error_log_file" >> "$summary_file"
    echo >> "$summary_file"

    # Store full logs in separate file
    full_log_file="../${s}.full.log"
    cp "$log_file" "$full_log_file"
    echo "Full Log Entries saved to: $full_log_file" >> "$summary_file"
    echo >> "$summary_file"

done < "$online_services"

echo "Summary generated: $summary_file"

read -p "View summary? (yes/no): " ans
[ "$ans" = "yes" ] && less "$summary_file"

