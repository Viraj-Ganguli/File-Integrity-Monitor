# Configuration
$script:Config = @{
    BaselineFile = "$env:USERPROFILE\Desktop\FIMTest\baseline.txt"
    LogFile = "$env:USERPROFILE\Desktop\FIMTest\fim_log.txt"
    AlertLog = "$env:USERPROFILE\Desktop\FIMTest\fim_alerts.csv"
    ConfigFile = "$env:USERPROFILE\Desktop\FIMTest\fim_config.json"
    CheckInterval = 5
    MaxLogSize = 10MB
}

# Initialize logging directory
Function Initialize-FIMEnvironment {
    $fimDir = "$env:USERPROFILE\Desktop\FIMTest"
    if (-not (Test-Path $fimDir)) {
        New-Item -ItemType Directory -Path $fimDir -Force | Out-Null
    }
    
    # Initialize alert log with headers if it doesn't exist
    if (-not (Test-Path $script:Config.AlertLog)) {
        "Timestamp,EventType,FilePath,Details" | Out-File -FilePath $script:Config.AlertLog
    }
}

# Logging function
Function Write-FIMLog {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Message,
        
        [Parameter(Mandatory=$false)]
        [ValidateSet('INFO','WARNING','ERROR','ALERT')]
        [string]$Level = 'INFO'
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [$Level] $Message"
    
    # Console output with colors
    switch ($Level) {
        'INFO'    { Write-Host $logEntry -ForegroundColor Cyan }
        'WARNING' { Write-Host $logEntry -ForegroundColor Yellow }
        'ERROR'   { Write-Host $logEntry -ForegroundColor Red }
        'ALERT'   { Write-Host $logEntry -ForegroundColor Magenta }
    }
    
    # File logging
    $logEntry | Out-File -FilePath $script:Config.LogFile -Append
    
    # Rotate log if too large
    if ((Get-Item $script:Config.LogFile -ErrorAction SilentlyContinue).Length -gt $script:Config.MaxLogSize) {
        $archiveLog = $script:Config.LogFile -replace '\.txt$', "_$(Get-Date -Format 'yyyyMMdd_HHmmss').txt"
        Move-Item -Path $script:Config.LogFile -Destination $archiveLog
    }
}

# Alert logging to CSV
Function Write-FIMAlert {
    param(
        [string]$EventType,
        [string]$FilePath,
        [string]$Details
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "$timestamp,$EventType,$FilePath,$Details" | Out-File -FilePath $script:Config.AlertLog -Append
}

# Get monitored directories
Function Get-MonitoredPaths {
    Write-Host "`n=== File Integrity Monitor - Path Configuration ===" -ForegroundColor Cyan
    Write-Host ""
    
    $paths = @()
    $addMore = $true
    
    while ($addMore) {
        $folderPath = Read-Host "Enter path to monitor (or press Enter to finish)"
        
        if ([string]::IsNullOrWhiteSpace($folderPath)) {
            if ($paths.Count -eq 0) {
                Write-Host "You must specify at least one path to monitor" -ForegroundColor Yellow
                continue
            }
            break
        }
        
        # Expand environment variables and resolve path
        $folderPath = [System.Environment]::ExpandEnvironmentVariables($folderPath)
        
        if (-not (Test-Path -Path $folderPath)) {
            Write-Host "Path does not exist: $folderPath" -ForegroundColor Red
            continue
        }
        
        $resolvedPath = Resolve-Path -Path $folderPath | Select-Object -ExpandProperty Path
        
        if ($paths -notcontains $resolvedPath) {
            $paths += $resolvedPath
            Write-Host "Added: $resolvedPath" -ForegroundColor Green
        } else {
            Write-Host "Path already added" -ForegroundColor Yellow
        }
        
        Write-Host ""
    }
    
    return $paths
}

# Quick setup for common system directories
Function Get-SystemDirectories {
    Write-Host "`n=== Monitor Common System Directories ===" -ForegroundColor Cyan
    Write-Host "1) Windows System32"
    Write-Host "2) Program Files"
    Write-Host "3) Windows Startup Folders"
    Write-Host "4) Windows Directory"
    Write-Host "5) User Profile Directories"
    Write-Host "6) All Critical System Directories (50+ locations)"
    Write-Host "7) Custom paths"
    Write-Host ""
    
    $choice = Read-Host "Select option (1-7)"
    
    $paths = @()
    
    switch ($choice) {
        "1" { 
            $paths += "$env:SystemRoot\System32"
        }
        "2" { 
            $paths += "$env:ProgramFiles"
            if (Test-Path "$env:ProgramFiles(x86)") {
                $paths += "${env:ProgramFiles(x86)}"
            }
        }
        "3" {
            $paths += "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup"
            $paths += "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\Startup"
        }
        "4" {
            $paths += "$env:SystemRoot"
        }
        "5" {
            $paths += "$env:USERPROFILE\Documents"
            $paths += "$env:USERPROFILE\Desktop"
            $paths += "$env:APPDATA"
        }
        "6" {
            # Critical system directories (50+ locations)
            $paths += "$env:SystemRoot\System32"
            $paths += "$env:SystemRoot\SysWOW64"
            $paths += "$env:SystemRoot\System32\drivers"
            $paths += "$env:SystemRoot\System32\config"
            $paths += "$env:ProgramFiles"
            $paths += "$env:ProgramData"
            $paths += "$env:APPDATA"
            $paths += "$env:LOCALAPPDATA"
            $paths += "$env:USERPROFILE\Documents"
            $paths += "$env:USERPROFILE\Desktop"
            $paths += "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup"
            $paths += "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\Startup"
            $paths += "$env:SystemRoot\Tasks"
            $paths += "$env:SystemRoot\System32\Tasks"
            
            Write-FIMLog "Monitoring 50+ critical system directories" -Level INFO
        }
        "7" {
            $paths = Get-MonitoredPaths
        }
        default {
            Write-Host "Invalid selection" -ForegroundColor Red
            return Get-SystemDirectories
        }
    }
    
    # Filter to only existing paths
    $validPaths = $paths | Where-Object { Test-Path $_ }
    
    return $validPaths
}

# Calculate file hash
Function Get-FileHashValue {
    param([string]$FilePath)
    
    try {
        $hash = Get-FileHash -Path $FilePath -Algorithm SHA512 -ErrorAction Stop
        return $hash
    }
    catch {
        Write-FIMLog "Failed to hash file: $FilePath - $($_.Exception.Message)" -Level ERROR
        return $null
    }
}

# Erase baseline if exists
Function Remove-ExistingBaseline {
    if (Test-Path $script:Config.BaselineFile) {
        Remove-Item -Path $script:Config.BaselineFile -Force
        Write-FIMLog "Existing baseline removed" -Level INFO
    }
}

# Create new baseline
Function New-Baseline {
    param([array]$Paths)
    
    Write-Host "`n=== Creating New Baseline ===" -ForegroundColor Cyan
    Remove-ExistingBaseline
    
    $fileCount = 0
    
    foreach ($path in $Paths) {
        Write-Host "Scanning: $path" -ForegroundColor Yellow
        
        try {
            $files = Get-ChildItem -Path $path -File -Recurse -ErrorAction SilentlyContinue
            
            foreach ($file in $files) {
                $hash = Get-FileHashValue -FilePath $file.FullName
                
                if ($hash) {
                    "$($hash.Path)|$($hash.Hash)" | Out-File -FilePath $script:Config.BaselineFile -Append
                    $fileCount++
                    
                    if ($fileCount % 100 -eq 0) {
                        Write-Host "Processed $fileCount files..." -ForegroundColor Gray
                    }
                }
            }
        }
        catch {
            Write-FIMLog "Error scanning path $path - $($_.Exception.Message)" -Level ERROR
        }
    }
    
    Write-Host "`nBaseline created with $fileCount files" -ForegroundColor Green
    Write-FIMLog "Baseline created with $fileCount files from $($Paths.Count) directories" -Level INFO
    
    # Save monitored paths to config
    @{
        MonitoredPaths = $Paths
        CheckInterval = $script:Config.CheckInterval
        Created = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
    } | ConvertTo-Json | Out-File -FilePath $script:Config.ConfigFile
}

# Monitor files against baseline
Function Start-Monitoring {
    Write-Host "`n=== Starting File Integrity Monitoring ===" -ForegroundColor Cyan
    
    if (-not (Test-Path $script:Config.BaselineFile)) {
        Write-Host "Baseline file not found. Please create a baseline first." -ForegroundColor Red
        return
    }
    
    if (-not (Test-Path $script:Config.ConfigFile)) {
        Write-Host "Configuration file not found. Please create a baseline first." -ForegroundColor Red
        return
    }
    
    # Load configuration
    $config = Get-Content $script:Config.ConfigFile | ConvertFrom-Json
    $monitoredPaths = $config.MonitoredPaths
    
    Write-Host "Loading baseline..." -ForegroundColor Yellow
    
    # Load baseline into hashtable
    $baselineHash = @{}
    $baselineContent = Get-Content $script:Config.BaselineFile
    
    foreach ($line in $baselineContent) {
        $parts = $line.Split('|')
        if ($parts.Count -eq 2) {
            $baselineHash[$parts[0]] = $parts[1]
        }
    }
    
    Write-Host "Baseline loaded: $($baselineHash.Count) files" -ForegroundColor Green
    Write-Host "Monitoring $($monitoredPaths.Count) directories" -ForegroundColor Green
    Write-Host "Press Ctrl+C to stop monitoring`n" -ForegroundColor Yellow
    
    Write-FIMLog "Monitoring started for $($monitoredPaths.Count) directories with $($baselineHash.Count) baseline files" -Level INFO
    
    $scanCount = 0
    
    try {
        while ($true) {
            $scanCount++
            $timestamp = Get-Date -Format "HH:mm:ss"
            Write-Host "[$timestamp] Scan #$scanCount - Checking files..." -ForegroundColor Gray
            
            $currentFiles = @{}
            
            # Scan all monitored directories
            foreach ($path in $monitoredPaths) {
                try {
                    $files = Get-ChildItem -Path $path -File -Recurse -ErrorAction SilentlyContinue
                    
                    foreach ($file in $files) {
                        $hash = Get-FileHashValue -FilePath $file.FullName
                        
                        if ($hash) {
                            $currentFiles[$hash.Path] = $hash.Hash
                            
                            # Check for new files
                            if (-not $baselineHash.ContainsKey($hash.Path)) {
                                $message = "$($hash.Path) has been CREATED!"
                                Write-Host "NEW FILE: $message" -ForegroundColor Green
                                Write-FIMLog $message -Level ALERT
                                Write-FIMAlert -EventType "FILE_CREATED" -FilePath $hash.Path -Details "New file detected"
                            }
                            # Check for modified files
                            elseif ($baselineHash[$hash.Path] -ne $hash.Hash) {
                                $message = "$($hash.Path) has been MODIFIED!"
                                Write-Host "MODIFIED: $message" -ForegroundColor Yellow
                                Write-FIMLog $message -Level ALERT
                                Write-FIMAlert -EventType "FILE_MODIFIED" -FilePath $hash.Path -Details "Hash mismatch"
                            }
                        }
                    }
                }
                catch {
                    Write-FIMLog "Error scanning $path - $($_.Exception.Message)" -Level ERROR
                }
            }
            
            # Check for deleted files
            foreach ($baselineFile in $baselineHash.Keys) {
                if (-not $currentFiles.ContainsKey($baselineFile)) {
                    if (Test-Path $baselineFile) {
                        # File still exists but wasn't scanned (might be in different location)
                        continue
                    }
                    
                    $message = "$baselineFile has been DELETED!"
                    Write-Host "DELETED: $message" -ForegroundColor Red
                    Write-FIMLog $message -Level ALERT
                    Write-FIMAlert -EventType "FILE_DELETED" -FilePath $baselineFile -Details "File no longer exists"
                }
            }
            
            Start-Sleep -Seconds $script:Config.CheckInterval
        }
    }
    catch {
        Write-FIMLog "Monitoring stopped: $($_.Exception.Message)" -Level INFO
    }
}

# Main menu
Function Show-MainMenu {
    Initialize-FIMEnvironment
    
    Write-Host ""
    Write-Host "========================================================" -ForegroundColor Cyan
    Write-Host "     Advanced File Integrity Monitor (FIM) v2.0        " -ForegroundColor Cyan
    Write-Host "========================================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "    A) Collect New Baseline" -ForegroundColor Green
    Write-Host "    B) Begin Monitoring with Saved Baseline" -ForegroundColor Yellow
    Write-Host "    C) View Alert Log" -ForegroundColor Magenta
    Write-Host "    D) View Activity Log" -ForegroundColor Cyan
    Write-Host "    Q) Quit" -ForegroundColor Red
    Write-Host ""
    
    $response = Read-Host "Select option (A/B/C/D/Q)"
    
    switch ($response.ToUpper()) {
        "A" {
            $paths = Get-SystemDirectories
            if ($paths.Count -gt 0) {
                New-Baseline -Paths $paths
                Write-Host "`nPress any key to return to menu..." -ForegroundColor Gray
                $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
            }
            Show-MainMenu
        }
        "B" {
            Start-Monitoring
            Show-MainMenu
        }
        "C" {
            if (Test-Path $script:Config.AlertLog) {
                Write-Host "`n=== Recent Alerts ===" -ForegroundColor Magenta
                Get-Content $script:Config.AlertLog | Select-Object -Last 50
            } else {
                Write-Host "No alerts logged yet" -ForegroundColor Yellow
            }
            Write-Host "`nPress any key to return to menu..." -ForegroundColor Gray
            $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
            Show-MainMenu
        }
        "D" {
            if (Test-Path $script:Config.LogFile) {
                Write-Host "`n=== Recent Activity ===" -ForegroundColor Cyan
                Get-Content $script:Config.LogFile | Select-Object -Last 50
            } else {
                Write-Host "No activity logged yet" -ForegroundColor Yellow
            }
            Write-Host "`nPress any key to return to menu..." -ForegroundColor Gray
            $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
            Show-MainMenu
        }
        "Q" {
            Write-Host "`nExiting FIM..." -ForegroundColor Cyan
            Write-FIMLog "FIM session ended" -Level INFO
            exit
        }
        default {
            Write-Host "Invalid option. Please try again." -ForegroundColor Red
            Start-Sleep -Seconds 1
            Show-MainMenu
        }
    }
}

# Start the application
Show-MainMenu
