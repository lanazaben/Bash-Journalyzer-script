
# 🧾 Journalyzer - Keyword Analysis

## Overview

**Journalyzer** is a Linux shell script that automates system log analysis using `journalctl`.
It extracts logs for specified services over a defined time range, searches for key terms, and generates summary reports.
The script is ideal for system administrators who want quick insights into service activity, error patterns, and keyword-based alerting.

---

## 🧠 Features

* ✅ Reads configuration from `/etc/journalyzer.conf`
* ✅ Collects logs for multiple services (kernel, sshd, cron, NetworkManager, systemd)
* ✅ Performs keyword frequency analysis across all extracted logs
* ✅ Generates a CSV report summarizing keyword counts
* ✅ Produces a time-based summary report with log statistics
* ✅ Triggers an alert if keyword occurrences exceed a defined threshold
* ✅ Offers an option to display the summary interactively

---

## ⚙️ Configuration File

The script requires a configuration file located at:

```
/etc/journalyzer.conf
```

### Example Configuration:

```ini
# Time range for journalctl (e.g., "1 hour ago", "2024-10-01", etc.)
time_="4 hours ago"

# Comma-separated list of services to analyze
service=kernel,sshd,NetworkManager,systemd,cron

# Directory to store generated reports
report="/var/log/journalyzer_reports"

# Keywords to search for in logs (comma-separated)
keywords="error,failed,timeout,disconnect"

# Alert threshold (total keyword occurrences)
ALERT_THRESHOLD=20
```

---

## 🧩 How It Works

### **Phase 1: Log Extraction**

* Reads the specified services from the configuration.
* Runs `journalctl` to extract logs for each service within the defined `time_` range.
* Saves each service’s logs into a separate `.log` file under the `report` directory.

### **Phase 2: Keyword Analysis**

* Reads keywords and alert threshold from the configuration.
* Counts occurrences of each keyword per service.
* Displays the results in a formatted table on screen.
* Saves results into a CSV report:

  ```
  keyword_analysis.csv
  ```

### **Phase 3: Alert Check**

* Sums total keyword counts across all services.
* If the total exceeds `ALERT_THRESHOLD`, an alert message is displayed.

### **Phase 4: Time-Based Summary**

* Generates a detailed text summary file containing:

  * Service name
  * Total log entries
  * First and last log timestamps
  * Peak activity hour
  * Keyword occurrence breakdown per service
* Saved as:

  ```
  summary-YYYY-MM-DD.txt
  ```
* User can choose to view the summary immediately after execution.

---

## 🖥️ Example Usage

1. Make the script executable:

   ```bash
   chmod +x journalyzer.sh
   ```

2. Run the script as root (required for journal access):

   ```bash
   sudo ./journalyzer.sh
   ```

3. Follow on-screen instructions — you’ll be asked whether to view the summary report.

---

## 📂 Output Files

All generated reports are saved in the directory specified by the `report` field in `/etc/journalyzer.conf`.

| File                           | Description                                                |
| ------------------------------ | ---------------------------------------------------------- |
| `kernel.log`, `sshd.log`, etc. | Raw logs per service                                       |
| `keyword_analysis.csv`         | Keyword occurrence summary                                 |
| `summary-YYYY-MM-DD.txt`       | Detailed log summary with timestamps and keyword breakdown |
| `error.log`                    | Unknown or invalid service entries                         |

---

## ⚠️ Error Handling

The script includes built-in validation to ensure reliability:

* Detects missing configuration file or fields (`time_`, `service`, `report`).
* Creates the report directory automatically if it doesn’t exist.
* Skips empty or missing log files.
* Logs unrecognized service names into `error.log`.
* Gracefully exits with informative messages for configuration errors.

---

## 🧰 Requirements

* Linux system using `systemd`
* Access to `journalctl`
* Root or sufficient privileges to read system logs

---

## 🧑‍💻 Author

**Lana Zaben**
]Project: *Journalyzer - Keyword Analysis Script*
