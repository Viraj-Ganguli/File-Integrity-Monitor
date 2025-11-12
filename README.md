# Advanced File Integrity Monitor (FIM)

A PowerShell-based File Integrity Monitor that performs baseline creation and continuous monitoring of file systems for creation, modification, and deletion events. The tool provides real-time console output, file-based logging, and a CSV alert log for easy ingestion by other tooling or SIEMs.

---

## Features

* Create a SHA-512 baseline of files under one or more directories.
* Periodic scanning to detect file **creation**, **modification**, and **deletion**.
* Console output with color-coded levels (INFO, WARNING, ERROR, ALERT).
* Persistent logs:

  * Activity log (`fim_log.txt`) with basic rotation when exceeding `MaxLogSize`.
  * Alert CSV (`fim_alerts.csv`) containing timestamped events for easy parsing.
* Interactive menu for baseline creation, monitoring, and quick access to logs.
* Quick presets to monitor common Windows system directories (System32, Program Files, Startup folders, user profile locations, etc.).
* Configurable scan interval and file locations via a script-level configuration hash.

---

## Requirements

* Windows PowerShell 5.1 (the script header includes `#Requires -Version 5.1`)
* Recommended: Run with elevated privileges (Administrator) when monitoring system-level directories.
* Sufficient file system read access to directories you intend to monitor.

---

## File layout (single-file script)

```
Advanced-FIM/
└── fim.ps1              # Main script (contains configuration, functions, and menu)
```

> The distribution you provided is implemented as a single PowerShell script that contains configuration, helper functions, baseline creation, monitoring loop, and an interactive menu.

---

## Configuration

The script exposes a single configuration hash at the top of the file:

```powershell
$script:Config = @{
    BaselineFile = "$env:USERPROFILE\Desktop\FIMTest\baseline.txt"
    LogFile      = "$env:USERPROFILE\Desktop\FIMTest\fim_log.txt"
    AlertLog     = "$env:USERPROFILE\Desktop\FIMTest\fim_alerts.csv"
    ConfigFile   = "$env:USERPROFILE\Desktop\FIMTest\fim_config.json"
    CheckInterval= 5             # seconds between scans
    MaxLogSize   = 10MB          # max activity log size before rotation
}
```

Change the values to point to alternate paths or adjust `CheckInterval` and `MaxLogSize` before running the script.

**Note:** `MaxLogSize` in the script uses a human-friendly string — if you modify the script logic to compare numeric sizes, ensure the value is parsed as bytes.

---

## Installation & Execution

1. Save the script as `fim.ps1` (or another name) on the host you plan to monitor.

2. (Optional) Allow script execution for the current user if not already enabled:

```powershell
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
```

3. Open PowerShell (recommended: Run as Administrator) and run:

```powershell
.\fim.ps1
```

4. The script launches an interactive menu with options to:

* `A` — Create a new baseline
* `B` — Begin monitoring using the saved baseline
* `C` — View recent alert log entries
* `D` — View recent activity log entries
* `Q` — Quit

---

## Typical Workflow

1. Run the script: `.\fim.ps1`
2. From the menu choose `A` to collect a new baseline.

   * Select directories to include (use the quick presets or provide custom paths).
   * The script will recursively traverse the selected directories and write `Path|SHA512Hash` entries to the baseline file.
3. From the menu choose `B` to start continuous monitoring.

   * The script will compare current file hashes to the baseline and log alerts for new, modified, or deleted files.
   * Alerts are appended to `fim_alerts.csv` as `Timestamp,EventType,FilePath,Details`.

---

## Log formats

* **Activity log (`fim_log.txt`)**

  * Plain text entries in the form: `[YYYY-MM-DD HH:mm:ss] [LEVEL] Message`
  * Rotates to a timestamped file once the file exceeds `MaxLogSize`.

* **Alert CSV (`fim_alerts.csv`)**

  * CSV header: `Timestamp,EventType,FilePath,Details`
  * Example row:

    ```
    2025-11-12 14:03:21,FILE_MODIFIED,C:\Windows\System32\drivers\abc.sys,Hash mismatch
    ```

* **Baseline (`baseline.txt`)**

  * Each line: `FullFilePath|SHA512Hash`

* **Config file (`fim_config.json`)**

  * JSON object with `MonitoredPaths`, `CheckInterval`, and `Created` timestamp saved when a baseline is created.

---

## Important Notes & Recommendations

* **Permissions:** Monitoring system directories (System32, Program Files, etc.) typically requires Administrator privileges. Running without sufficient permissions may cause incomplete baseline creation or false positives.
* **Performance:** Recursive hashing of many files (especially on large system directories) is I/O and CPU intensive. Consider:

  * Narrowing monitored paths.
  * Increasing `CheckInterval`.
  * Running initial baseline creation during off-peak hours.
* **Exclusions:** If needed, extend the script to accept exclude patterns (by file extension, filename regex, or path blacklist) to reduce noise and CPU usage.
* **Baseline maintenance:** When legitimate changes are made (updates, software installs), update the baseline by re-creating it or implementing a trusted update workflow.
* **False positives:** Temporary files, logs, and dynamically generated files will frequently change. Exclude or handle such locations explicitly if they are not relevant.
* **File locks/access errors:** Some files may be inaccessible (locked or restricted). The script currently logs hashing failures to the activity log.

---

## Troubleshooting

* **Script won’t run** — verify execution policy and PowerShell version:

  ```powershell
  $PSVersionTable.PSVersion
  Get-ExecutionPolicy -List
  ```
* **Baseline creation stalls or errors** — ensure you have read permissions for target directories and that the machine has sufficient resources.
* **Large log file never rotates** — confirm `MaxLogSize` is parsed and compared as bytes; if you change the format, adjust rotation logic accordingly.
* **Many spurious alerts** — add exclude rules for temporary, cache, or log directories (not present in the current script but recommended as an enhancement).

---

## Security & Legal

This tool is intended for authorized use only. Do not run it against systems you do not own or for which you do not have explicit permission. Running file integrity monitoring on critical production systems should follow established change-control processes and be tested in a staging environment first.

---

## Future Enhancements (suggested)

* Add configuration-driven exclusion rules (by path, extension, or regex).
* Add finer-grained scheduling (cron-like or Windows Task Scheduler integration).
* Implement a persistent service/daemon mode (run headless as a scheduled task or Windows service).
* Support incremental hashing or change journals (USN change journal) to reduce full-file hashing overhead.
* Add email, syslog, or webhook alerting integrations.
* Add signed baselines and authenticated baseline updates for tamper resistance.
* Provide optional JSON output and integration points for SIEM ingestion.

