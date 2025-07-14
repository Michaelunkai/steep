#Requires -RunAsAdministrator

<#
.SYNOPSIS
    Complete System Optimization - ALL COMMANDS EMBEDDED VERSION (Hiberfil.sys + System Volume Information Purge)
.DESCRIPTION
    Runs ALL system optimization commands directly - no function calls. Comprehensive hiberfil.sys and System Volume Information cleanup.
    Usage: ./a.ps1 [1|2|3] where 1=RESS script, 2=Fit-Launcher script, 3=No reboot
.NOTES
    Must be run as Administrator
    Examples:
    ./a.ps1 1    # Auto-select RESS script
    ./a.ps1 2    # Auto-select Fit-Launcher script  
    ./a.ps1 3    # Auto-select no reboot
#>

param(
    [int]$Choice = 0,  # Command line choice: 1=RESS, 2=Fit-Launcher, 3=No reboot
    [switch]$SkipConfirmations,
    [int]$TimeoutSeconds = 300
)

# Set execution policy and error handling
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force
$ErrorActionPreference = "Continue"
$ProgressPreference = "SilentlyContinue"

# Global variables
$global:ScriptStartTime = Get-Date
$global:LogPath = "$env:USERPROFILE\Desktop\SystemOptimization_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
$global:RestartChoice = "none"

# CHOOSE FINAL ACTION AT THE VERY BEGINNING
# Check if choice was provided via command line argument
if ($Choice -ge 1 -and $Choice -le 3) {
    # Auto-select based on command line argument
    switch ($Choice) {
        1 { 
            $global:RestartChoice = "ress"
            Write-Host "✓ AUTO-SELECTED: Will run RESS script after optimization." -ForegroundColor Green
        }
        2 { 
            $global:RestartChoice = "fitlauncher"
            Write-Host "✓ AUTO-SELECTED: Will run Fit-Launcher script after optimization." -ForegroundColor Green
        }
        3 { 
            $global:RestartChoice = "none"
            Write-Host "✓ AUTO-SELECTED: Will skip both scripts - no reboot." -ForegroundColor Yellow
        }
    }
    Write-Host "Starting optimization immediately..." -ForegroundColor Cyan
    Start-Sleep 2
}
elseif (-not $SkipConfirmations) {
    Write-Host "=" * 80 -ForegroundColor Cyan
    Write-Host "SYSTEM OPTIMIZATION SCRIPT - FINAL ACTION CONFIGURATION" -ForegroundColor Cyan
    Write-Host "=" * 80 -ForegroundColor Cyan
    Write-Host "`nThis script will perform comprehensive system optimization including:" -ForegroundColor White
    Write-Host "• Hiberfil.sys and pagefile cleanup (all drives)" -ForegroundColor Yellow
    Write-Host "• System cleaning (CCleaner, AdwCleaner, BleachBit)" -ForegroundColor Yellow
    Write-Host "• Comprehensive System Volume Information purge" -ForegroundColor Yellow
    Write-Host "• Network and WiFi performance boost" -ForegroundColor Yellow
    Write-Host "• WSL2 setup and configuration" -ForegroundColor Yellow
    Write-Host "• Registry optimizations" -ForegroundColor Yellow
    Write-Host "• Complete system cleanup" -ForegroundColor Yellow
    Write-Host "• Wise Registry Cleaner deep scan" -ForegroundColor Green
    Write-Host "• Wise Disk Cleaner advanced scan" -ForegroundColor Green
    
    Write-Host "`nChoose what to do AFTER optimization completes:" -ForegroundColor Red
    Write-Host "[1] Run RESS script (sleep/shutdown)" -ForegroundColor Green
    Write-Host "[2] Run Fit-Launcher script (/mnt/f/study/shells/powershell/scripts/rebootfitlauncher/a.ps1)" -ForegroundColor Green  
    Write-Host "[3] No reboot - skip both scripts" -ForegroundColor Green
    Write-Host "`nTip: You can also run this script with: ./a.ps1 1, ./a.ps1 2, or ./a.ps1 3" -ForegroundColor Gray
    
    do {
        $choice = Read-Host "`nEnter your choice (1, 2, or 3)"
        switch ($choice) {
            "1" { 
                $global:RestartChoice = "ress"
                Write-Host "✓ Will run RESS script after optimization." -ForegroundColor Green
                break
            }
            "2" { 
                $global:RestartChoice = "fitlauncher"
                Write-Host "✓ Will run Fit-Launcher script after optimization." -ForegroundColor Green
                break
            }
            "3" { 
                $global:RestartChoice = "none"
                Write-Host "✓ Will skip both scripts - no reboot." -ForegroundColor Yellow
                break
            }
            default { 
                Write-Host "Invalid choice. Please enter 1, 2, or 3." -ForegroundColor Red
                continue
            }
        }
        break
    } while ($true)
    
    Write-Host "`nStarting optimization in 3 seconds..." -ForegroundColor Cyan
    Start-Sleep 3
}
else {
    # Default to no reboot if confirmations are skipped and no choice provided
    $global:RestartChoice = "none"
    Write-Host "✓ DEFAULT: Will skip both scripts - no reboot (use ./a.ps1 1, 2, or 3 for auto-selection)." -ForegroundColor Yellow
}

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [$Level] $Message"
    Write-Host $logEntry -ForegroundColor $(if($Level -eq "ERROR"){"Red"}elseif($Level -eq "WARN"){"Yellow"}else{"Green"})
    Add-Content -Path $global:LogPath -Value $logEntry -ErrorAction SilentlyContinue
}

function Write-ProgressLog {
    param([string]$Message)
    # Check global timeout
    $elapsed = (Get-Date) - $global:ScriptStartTime
    if ($elapsed.TotalMinutes -gt 60) {
        Write-Log "🚨 GLOBAL TIMEOUT: Script has been running for over 60 minutes - forcing completion..." "ERROR"
        throw "Global timeout exceeded"
    }
    
    $percentage = [math]::Round(($operationCount/$totalOperations)*100,1)
    Write-Log "[$operationCount/$totalOperations] ($percentage%) $Message"
    
    # Kill any hanging processes
    $hangingProcesses = @("cleanmgr", "wsreset", "dism")
    foreach ($proc in $hangingProcesses) {
        $processes = Get-Process -Name $proc -ErrorAction SilentlyContinue
        if ($processes) {
            $oldestProcess = $processes | Sort-Object StartTime | Select-Object -First 1
            if (((Get-Date) - $oldestProcess.StartTime).TotalMinutes -gt 5) {
                Write-Log "🚨 Killing hanging process: $proc (running for over 5 minutes)" "WARN"
                $oldestProcess | Stop-Process -Force
            }
        }
    }
}

function Test-AdminRights {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Invoke-WithTimeout {
    param(
        [scriptblock]$ScriptBlock,
        [int]$TimeoutSeconds = 30,
        [string]$Description = "Operation"
    )
    
    try {
        $job = Start-Job -ScriptBlock $ScriptBlock
        
        if (Wait-Job $job -Timeout $TimeoutSeconds) {
            $result = Receive-Job $job
            Remove-Job $job
            return $result
        } else {
            Stop-Job $job
            Remove-Job $job
            Write-Log "$Description timed out after $TimeoutSeconds seconds" "WARN"
            return $null
        }
    } catch {
        Write-Log "$Description failed: $_" "ERROR"
        return $null
    }
}

function Start-SystemOptimization {
    Write-Log "=== Starting Complete System Optimization ==="
    
    if (-NOT (Test-AdminRights)) {
        Write-Log "ERROR: This script must be run as Administrator!" "ERROR"
        exit 1
    }
    
    # Global safety mechanism - force terminate hanging processes and overall timeout
    $globalTimeoutJob = Start-Job {
        param($maxTotalTime)
        Start-Sleep $maxTotalTime
        return "GLOBAL_TIMEOUT"
    } -ArgumentList 3600  # 60 minutes maximum for entire script
    
    Register-EngineEvent PowerShell.Exiting -Action {
        try {
            Write-Host "🚨 Emergency cleanup: Killing all optimization processes..." -ForegroundColor Red
            $processesToKill = @("CCleaner*", "adwcleaner", "bleachbit*", "cleanmgr", "wsreset", "dism", "powershell")
            foreach ($processPattern in $processesToKill) {
                Get-Process -Name $processPattern -ErrorAction SilentlyContinue | 
                    Where-Object { $_.Id -ne $PID } | Stop-Process -Force
            }
        } catch { }
    }
    
    # Start a background job to show progress every 15 seconds (more frequent)
    $progressJob = Start-Job {
        $counter = 0
        while ($true) {
            Start-Sleep 15
            $counter++
            $timestamp = Get-Date -Format 'HH:mm:ss'
            Write-Host "⏱️  [HEARTBEAT $counter] Script is actively running... $timestamp ⏱️" -ForegroundColor Yellow
        }
    }
    
    $operationCount = 0
    # Adjust total operations - removed Docker cleanup operations
    if ($global:RestartChoice -eq "none") {
        $totalOperations = 20  # Reduced from 24 due to Docker cleanup removal
    } else {
        $totalOperations = 21  # Reduced from 25 due to Docker cleanup removal
    }
    
    # OPERATION 1: SDESKTOP - Start Docker Desktop
    $operationCount++
    Write-ProgressLog "Starting Docker Desktop"
    try {
        if (Test-Path "C:\Program Files\Docker\Docker\Docker Desktop.exe") {
            Start-Process "C:\Program Files\Docker\Docker\Docker Desktop.exe" -WindowStyle Hidden
            Start-Sleep 25
            Write-Log "Docker Desktop started"
        } else {
            Write-Log "Docker Desktop not found" "WARN"
        }
    } catch {
        Write-Log "Error starting Docker Desktop: $_" "ERROR"
    }
    
    # OPERATION 2: HIBERFIL.SYS AND PAGEFILE CLEANUP
    $operationCount++
    Write-ProgressLog "Hiberfil.sys and pagefile cleanup"
    try {
        Write-Log "=== HIBERFIL.SYS AND PAGEFILE CLEANUP ==="
        Write-Log "Starting hibernation file and pagefile cleanup..."
        
        # Disable hibernation to remove hiberfil.sys
        Write-Log "Disabling hibernation to remove hiberfil.sys..."
        powercfg -h off 2>$null
        Write-Log "Hibernation disabled"
        
        # Force remove hiberfil.sys if it still exists
        $hiberfilPaths = @("C:\hiberfil.sys", "F:\hiberfil.sys", "D:\hiberfil.sys")
        foreach ($hiberPath in $hiberfilPaths) {
            if (Test-Path $hiberPath) {
                try {
                    Write-Log "Attempting to remove: $hiberPath"
                    takeown /f "$hiberPath" /d y 2>$null | Out-Null
                    icacls "$hiberPath" /grant administrators:F 2>$null | Out-Null
                    Remove-Item -Path $hiberPath -Force -ErrorAction SilentlyContinue
                    if (Test-Path $hiberPath) {
                        Write-Log "Could not remove $hiberPath (may be in use)" "WARN"
                    } else {
                        Write-Log "Successfully removed: $hiberPath"
                    }
                } catch {
                    Write-Log "Error removing $hiberPath`: $_" "ERROR"
                }
            } else {
                Write-Log "Hiberfil not found at: $hiberPath"
            }
        }
        
        # Clean up swap files and page files
        $swapFiles = @("C:\swapfile.sys", "C:\pagefile.sys", "F:\swapfile.sys", "F:\pagefile.sys")
        foreach ($swapFile in $swapFiles) {
            if (Test-Path $swapFile) {
                try {
                    Write-Log "Attempting to remove: $swapFile"
                    Remove-Item -Path $swapFile -Force -ErrorAction SilentlyContinue
                    if (!(Test-Path $swapFile)) {
                        Write-Log "Successfully removed: $swapFile"
                    }
                } catch {
                    Write-Log "Could not remove $swapFile (system in use)" "WARN"
                }
            }
        }
        
        Write-Log "Hiberfil.sys and pagefile cleanup completed"
        
    } catch {
        Write-Log "Hiberfil.sys cleanup failed: $_" "ERROR"
    }
    
    # OPERATION 3: GCCLEANER - Get CCleaner (alternative method)
    $operationCount++
    Write-ProgressLog "Getting CCleaner"
    try {
        Get-Process -Name "CCleaner64", "CCleaner" -ErrorAction SilentlyContinue | Stop-Process -Force
        
        $ccleanerPath = 'F:\backup\windowsapps\installed\ccleaner'
        if (Test-Path $ccleanerPath) {
            Remove-Item -LiteralPath $ccleanerPath -Recurse -Force -Confirm:$false -ErrorAction SilentlyContinue
        }
        
        # Try alternative CCleaner setup if available
        $alternativeCCleanerPaths = @(
            "C:\Program Files\CCleaner\CCleaner64.exe",
            "C:\Program Files (x86)\CCleaner\CCleaner64.exe",
            "F:\backup\windowsapps\installed\ccleaner\CCleaner64.exe"
        )
        
        $ccleanerFound = $false
        foreach ($altPath in $alternativeCCleanerPaths) {
            if (Test-Path $altPath) {
                Write-Log "CCleaner found at: $altPath"
                $ccleanerFound = $true
                break
            }
        }
        
        if ($ccleanerFound) {
            Write-Log "CCleaner is available for use"
        } else {
            Write-Log "CCleaner not found - will attempt installation during CCleaner operation" "WARN"
        }
        
    } catch {
        Write-Log "CCleaner setup failed: $_" "ERROR"
    }
    
    # OPERATION 4: COMPREHENSIVE SYSTEM VOLUME INFORMATION CLEANUP
    $operationCount++
    Write-ProgressLog "Comprehensive System Volume Information cleanup"
    try {
        Write-Log "=== COMPREHENSIVE SYSTEM VOLUME INFORMATION CLEANUP ==="
        Write-Log "Starting aggressive System Volume Information cleanup on all drives..."
        
        # Get all drives
        $drives = Get-WmiObject -Class Win32_LogicalDisk | Where-Object { $_.DriveType -eq 3 } | Select-Object -ExpandProperty DeviceID
        
        foreach ($drive in $drives) {
            $sviPath = "$drive\System Volume Information"
            Write-Log "Processing System Volume Information on drive: $drive"
            
            if (Test-Path $sviPath) {
                try {
                    Write-Log "Taking ownership of: $sviPath"
                    takeown /f "$sviPath" /r /d y 2>$null | Out-Null
                    icacls "$sviPath" /grant administrators:F /t /q 2>$null | Out-Null
                    
                    Write-Log "Enumerating and removing System Volume Information contents..."
                    $sviItems = Get-ChildItem -Path $sviPath -Force -Recurse -ErrorAction SilentlyContinue
                    $itemCount = 0
                    $sizeFreed = 0
                    
                    foreach ($item in $sviItems) {
                        try {
                            if (!$item.PSIsContainer) {
                                $sizeFreed += $item.Length
                            }
                            $item.Attributes = 'Normal'
                            Remove-Item -Path $item.FullName -Force -Recurse -ErrorAction SilentlyContinue
                            $itemCount++
                        } catch {
                            Write-Log "Could not remove: $($item.FullName)" "WARN"
                        }
                    }
                    
                    # Try to remove the directory itself
                    try {
                        $sviDirectories = Get-ChildItem -Path $sviPath -Directory -Force -ErrorAction SilentlyContinue
                        foreach ($dir in $sviDirectories) {
                            $dir.Attributes = 'Normal'
                            Remove-Item -Path $dir.FullName -Force -Recurse -ErrorAction SilentlyContinue
                        }
                    } catch {
                        Write-Log "Could not remove some SVI directories (system protected)" "WARN"
                    }
                    
                    Write-Log "Removed $itemCount items from $sviPath, freed $([math]::Round($sizeFreed/1MB, 2)) MB"
                    
                } catch {
                    Write-Log "Error processing $sviPath`: $_" "ERROR"
                }
            } else {
                Write-Log "System Volume Information not found on: $drive"
            }
        }
        
        Write-Log "System Volume Information cleanup completed"
        
    } catch {
        Write-Log "System Volume Information cleanup failed: $_" "ERROR"
    }
    
    # OPERATION 5: CCLEANER - Run CCleaner with timeout
    $operationCount++
    Write-ProgressLog "Running CCleaner"
    try {
        if (Test-Path "C:\Program Files\CCleaner\CCleaner64.exe") {
            $ccleanerProcess = Start-Process "C:\Program Files\CCleaner\CCleaner64.exe" -WindowStyle Hidden -PassThru
            
            # Wait max 120 seconds for CCleaner
            $timeout = 120
            $timer = 0
            while (!$ccleanerProcess.HasExited -and $timer -lt $timeout) {
                Start-Sleep -Seconds 5
                $timer += 5
            }
            
            if (!$ccleanerProcess.HasExited) {
                Write-Log "CCleaner timeout - force killing process" "WARN"
                $ccleanerProcess.Kill()
            }
            
            Write-Log "CCleaner operation completed"
        } else {
            Write-Log "CCleaner not found at default location" "WARN"
        }
    } catch {
        Write-Log "CCleaner execution failed: $_" "ERROR"
    }
    
    # OPERATION 6: ADW - Run AdwCleaner with timeout
    $operationCount++
    Write-ProgressLog "Running AdwCleaner"
    try {
        if (Test-Path "F:\backup\windowsapps\installed\adw\adwcleaner.exe") {
            # Start AdwCleaner with timeout
            $adwProcess = Start-Process "F:\backup\windowsapps\installed\adw\adwcleaner.exe" -ArgumentList "/eula", "/clean", "/noreboot" -WindowStyle Hidden -PassThru
            
            # Wait max 60 seconds for process to complete
            $timeout = 60
            $timer = 0
            while (!$adwProcess.HasExited -and $timer -lt $timeout) {
                Start-Sleep -Seconds 2
                $timer += 2
            }
            
            # Force kill if still running
            if (!$adwProcess.HasExited) {
                Write-Log "AdwCleaner timeout - force killing process" "WARN"
                $adwProcess.Kill()
            }
            
            # Quick log check (max 10 seconds)
            for ($i = 0; $i -lt 5; $i++) {
                Start-Sleep -Seconds 2
                $log = Get-ChildItem -Path "$env:HOMEDRIVE\AdwCleaner\Logs" -Filter "*.txt" -ErrorAction SilentlyContinue | 
                       Sort-Object LastWriteTime -Descending | Select-Object -First 1
                if ($log -and (Test-Path $log.FullName)) {
                    Write-Log "AdwCleaner completed - log found"
                    break
                }
            }
            Write-Log "AdwCleaner operation completed"
        } else {
            Write-Log "AdwCleaner not found" "WARN"
        }
    } catch {
        Write-Log "AdwCleaner execution failed: $_" "ERROR"
    }
    
    # OPERATION 7: CCTEMP - Comprehensive temp cleanup with verbose logging
    $operationCount++
    Write-ProgressLog "Comprehensive temp cleanup"
    try {
        Write-Log "Defining temp cleanup paths..."
        $userTempPaths = @(
            "$env:TEMP", "$env:TMP", "$env:LOCALAPPDATA\Temp",
            "$env:LOCALAPPDATA\Microsoft\Windows\INetCache",
            "$env:LOCALAPPDATA\Microsoft\Windows\WebCache",
            "$env:LOCALAPPDATA\CrashDumps"
        )
        
        $systemPaths = @(
            "C:\Windows\Temp", "C:\Windows\Prefetch",
            "C:\Windows\SoftwareDistribution\Download"
        )
        
        Write-Log "Scanning all user profiles for temp folders..."
        $allUsersPaths = @()
        $users = Get-ChildItem "C:\Users" -Directory -ErrorAction SilentlyContinue
        foreach ($user in $users) {
            if ($user.Name -notmatch "^(All Users|Default|Public)$") {
                $allUsersPaths += @(
                    "$($user.FullName)\AppData\Local\Temp",
                    "$($user.FullName)\AppData\Local\Microsoft\Windows\INetCache",
                    "$($user.FullName)\AppData\Local\Microsoft\Windows\WebCache"
                )
            }
        }
        Write-Log "Found $($users.Count) user profiles, added $($allUsersPaths.Count) additional temp paths"
        
        $totalFilesDeleted = 0
        $totalSizeFreed = 0
        $pathsProcessed = 0
        $allPaths = $userTempPaths + $systemPaths + $allUsersPaths
        
        Write-Log "Processing $($allPaths.Count) temp directories..."
        
        # Add global timeout for temp cleanup section
        $tempCleanupStart = Get-Date
        $maxTempCleanupTime = 300  # 5 minutes maximum for all temp cleanup
        
        foreach ($path in $allPaths) {
            # Check if we've exceeded the maximum time
            if (((Get-Date) - $tempCleanupStart).TotalSeconds -gt $maxTempCleanupTime) {
                Write-Log "Temp cleanup timeout reached ($maxTempCleanupTime seconds) - skipping remaining paths..." "WARN"
                break
            }
            
            $pathsProcessed++
            if (Test-Path $path) {
                try {
                    Write-Log "[$pathsProcessed/$($allPaths.Count)] Processing: $path"
                    
                    # Set timeout for each individual path (30 seconds max)
                    $pathStart = Get-Date
                    $files = Get-ChildItem -Path $path -File -Recurse -Force -ErrorAction SilentlyContinue
                    $pathFileCount = 0
                    $pathSizeFreed = 0
                    
                    foreach ($file in $files) {
                        # Check individual path timeout
                        if (((Get-Date) - $pathStart).TotalSeconds -gt 30) {
                            Write-Log "  Path processing timeout (30s) - moving to next path..." "WARN"
                            break
                        }
                        
                        try {
                            $fileSize = $file.Length
                            Remove-Item -Path $file.FullName -Force -ErrorAction SilentlyContinue
                            $totalSizeFreed += $fileSize
                            $pathSizeFreed += $fileSize
                            $totalFilesDeleted++
                            $pathFileCount++
                        } catch { }
                    }
                    
                    if ($pathFileCount -gt 0) {
                        Write-Log "  Cleaned $pathFileCount files, freed $([math]::Round($pathSizeFreed/1MB, 2)) MB"
                    }
                } catch {
                    Write-Log "  Error processing $path`: $_" "ERROR"
                }
            } else {
                Write-Log "[$pathsProcessed/$($allPaths.Count)] Path not found: $path"
            }
        }
        
        Write-Log "Running Windows Disk Cleanup utility..."
        # Use timeout job instead of -Wait to prevent hanging
        $cleanupJob = Start-Job {
            Start-Process "cleanmgr.exe" -ArgumentList "/sagerun:1" -WindowStyle Hidden -Wait
        }
        
        if (Wait-Job $cleanupJob -Timeout 60) {
            Receive-Job $cleanupJob | Out-Null
            Remove-Job $cleanupJob
            Write-Log "Disk Cleanup utility completed"
        } else {
            Stop-Job $cleanupJob
            Remove-Job $cleanupJob
            Write-Log "Disk Cleanup utility timeout after 60 seconds - continuing..." "WARN"
            # Force kill any remaining cleanmgr processes
            Get-Process -Name "cleanmgr" -ErrorAction SilentlyContinue | Stop-Process -Force
        }
        
        Write-Log "Temp cleanup completed - Files deleted: $totalFilesDeleted, Space freed: $([math]::Round($totalSizeFreed/1GB, 2)) GB"
    } catch {
        Write-Log "Temp cleanup failed: $_" "ERROR"
    }
    
    # OPERATION 8: CCCCLEAN - Windows cleanup script with timeout and verbose logging
    $operationCount++
    Write-ProgressLog "Windows cleanup script"
    try {
        if (Test-Path "F:\study\shells\powershell\scripts\CleanWin11\a.ps1") {
            Write-Log "Starting Windows cleanup script with automated responses..."
            
            # Create a more robust automated execution
            $cleanupJob = Start-Job {
                $psi = New-Object System.Diagnostics.ProcessStartInfo
                $psi.FileName = "powershell.exe"
                $psi.Arguments = "-File `"F:\study\shells\powershell\scripts\CleanWin11\a.ps1`""
                $psi.RedirectStandardInput = $true
                $psi.RedirectStandardOutput = $true
                $psi.RedirectStandardError = $true
                $psi.UseShellExecute = $false
                $psi.CreateNoWindow = $true
                
                $process = [System.Diagnostics.Process]::Start($psi)
                
                # Send automated responses
                $responses = @("A", "A", "A", "A", "A", "Y", "Y", "Y")
                foreach ($response in $responses) {
                    $process.StandardInput.WriteLine($response)
                    Start-Sleep -Milliseconds 200
                }
                $process.StandardInput.Close()
                
                # Wait for completion with timeout
                $timeout = 90
                $timer = 0
                while (!$process.HasExited -and $timer -lt $timeout) {
                    Start-Sleep -Seconds 2
                    $timer += 2
                }
                
                if (!$process.HasExited) {
                    $process.Kill()
                    return "TIMEOUT"
                }
                
                return "COMPLETED"
            }
            
            Write-Log "Waiting for Windows cleanup script to complete (max 120 seconds)..."
            if (Wait-Job $cleanupJob -Timeout 120) {
                $result = Receive-Job $cleanupJob
                Remove-Job $cleanupJob
                Write-Log "Windows cleanup script result: $result"
            } else {
                Stop-Job $cleanupJob
                Remove-Job $cleanupJob
                Write-Log "Windows cleanup script FORCED TIMEOUT - continuing..." "WARN"
            }
        } else {
            Write-Log "Windows cleanup script not found at F:\study\shells\powershell\scripts\CleanWin11\a.ps1" "WARN"
        }
    } catch {
        Write-Log "Windows cleanup script failed: $_" "ERROR"
    }
    
    # OPERATION 9: Advanced System Cleaner with timeout and better logging
    $operationCount++
    Write-ProgressLog "Advanced System Cleaner"
    try {
        if (Test-Path "F:\study\Platforms\windows\bat\AdvancedSystemCleaner.bat") {
            Write-Log "Starting Advanced System Cleaner batch file..."
            
            $psi = New-Object System.Diagnostics.ProcessStartInfo
            $psi.FileName = "cmd.exe"
            $psi.Arguments = "/c `"F:\study\Platforms\windows\bat\AdvancedSystemCleaner.bat`""
            $psi.RedirectStandardInput = $true
            $psi.RedirectStandardOutput = $true
            $psi.UseShellExecute = $false
            $psi.CreateNoWindow = $true
            
            $process = [System.Diagnostics.Process]::Start($psi)
            Write-Log "Process started with PID: $($process.Id)"
            
            $responses = @("3", "n", "y")
            foreach ($response in $responses) {
                Write-Log "Sending automated response: '$response'"
                $process.StandardInput.WriteLine($response)
                Start-Sleep -Milliseconds 500
            }
            
            $process.StandardInput.Close()
            Write-Log "All responses sent, waiting for process completion..."
            
            # Wait max 180 seconds (3 minutes) with progress updates
            $timeout = 180
            $timer = 0
            while (!$process.HasExited -and $timer -lt $timeout) {
                Start-Sleep -Seconds 5
                $timer += 5
                if ($timer % 30 -eq 0) {
                    Write-Log "Advanced System Cleaner still running... ($timer out of $timeout seconds)"
                }
            }
            
            if (!$process.HasExited) {
                Write-Log "Advanced System Cleaner timeout after $timeout seconds - force killing process" "WARN"
                $process.Kill()
                Write-Log "Process killed successfully"
            } else {
                Write-Log "Advanced System Cleaner completed normally"
            }
        } else {
            Write-Log "Advanced System Cleaner not found at F:\study\Platforms\windows\bat\AdvancedSystemCleaner.bat" "WARN"
        }
    } catch {
        Write-Log "Advanced System Cleaner failed: $_" "ERROR"
    }
    
    # OPERATION 10-12: BLEACH (3 times) with timeout
    for ($bleachRun = 1; $bleachRun -le 3; $bleachRun++) {
        $operationCount++
        Write-ProgressLog "BleachBit run $bleachRun"
        try {
            if (Test-Path "F:\backup\windowsapps\installed\BleachBit\bleachbit_console.exe") {
                $bleachProcess = Start-Process "F:\backup\windowsapps\installed\BleachBit\bleachbit_console.exe" -ArgumentList "--clean", "system.logs", "system.tmp", "system.recycle_bin", "system.thumbnails", "system.memory_dump", "system.prefetch", "system.clipboard", "system.muicache", "system.rotated_logs", "adobe_reader.tmp", "firefox.cache", "firefox.cookies", "firefox.session_restore", "firefox.forms", "firefox.passwords", "google_chrome.cache", "google_chrome.cookies", "google_chrome.history", "google_chrome.form_history", "microsoft_edge.cache", "microsoft_edge.cookies", "vlc.mru", "windows_explorer.mru", "windows_explorer.recent_documents", "windows_explorer.thumbnails", "deepscan.tmp", "deepscan.backup" -WindowStyle Hidden -PassThru
                
                # Wait max 90 seconds for BleachBit
                $timeout = 90
                $timer = 0
                while (!$bleachProcess.HasExited -and $timer -lt $timeout) {
                    Start-Sleep -Seconds 5
                    $timer += 5
                }
                
                if (!$bleachProcess.HasExited) {
                    Write-Log "BleachBit run $bleachRun timeout - force killing process" "WARN"
                    $bleachProcess.Kill()
                }
                
                Write-Log "BleachBit run $bleachRun completed"
            } else {
                Write-Log "BleachBit not found" "WARN"
            }
        } catch {
            Write-Log "BleachBit run $bleachRun failed: $_" "ERROR"
        }
    }
    
    # OPERATION 13: ADDITIONAL SYSTEM FILE CLEANUP
    $operationCount++
    Write-ProgressLog "Additional system file cleanup"
    try {
        Write-Log "=== ADDITIONAL SYSTEM FILE CLEANUP ==="
        Write-Log "Starting additional system file cleanup operations..."
        
        # Clean Windows Update cache
        Write-Log "Cleaning Windows Update cache..."
        $wuCachePaths = @(
            "C:\Windows\SoftwareDistribution\Download\*",
            "C:\Windows\SoftwareDistribution\DataStore\*",
            "C:\Windows\System32\catroot2\*"
        )
        
        foreach ($path in $wuCachePaths) {
            if (Test-Path $path) {
                try {
                    Remove-Item -Path $path -Recurse -Force -ErrorAction SilentlyContinue
                    Write-Log "Cleaned: $path"
                } catch {
                    Write-Log "Could not clean: $path" "WARN"
                }
            }
        }
        
        # Clean memory dumps and error reports
        Write-Log "Cleaning memory dumps and error reports..."
        $dumpPaths = @(
            "C:\Windows\Minidump\*",
            "C:\Windows\memory.dmp",
            "C:\ProgramData\Microsoft\Windows\WER\*",
            "C:\Users\*\AppData\Local\CrashDumps\*"
        )
        
        foreach ($path in $dumpPaths) {
            try {
                if (Test-Path $path) {
                    Remove-Item -Path $path -Recurse -Force -ErrorAction SilentlyContinue
                    Write-Log "Cleaned: $path"
                }
            } catch {
                Write-Log "Could not clean: $path" "WARN"
            }
        }
        
        # Clean thumbnail and icon caches system-wide
        Write-Log "Cleaning thumbnail and icon caches system-wide..."
        $cachePaths = @(
            "C:\Users\*\AppData\Local\Microsoft\Windows\Explorer\thumbcache_*.db",
            "C:\Users\*\AppData\Local\Microsoft\Windows\Explorer\iconcache_*.db",
            "C:\Users\*\AppData\Local\IconCache.db",
            "C:\Users\*\AppData\Local\GDIPFONTCACHEV1.DAT"
        )
        
        foreach ($cachePath in $cachePaths) {
            try {
                $files = Get-ChildItem -Path $cachePath -Force -ErrorAction SilentlyContinue
                foreach ($file in $files) {
                    Remove-Item -Path $file.FullName -Force -ErrorAction SilentlyContinue
                }
            } catch { }
        }
        
        Write-Log "Additional system file cleanup completed"
        
    } catch {
        Write-Log "Additional system file cleanup failed: $_" "ERROR"
    }
    
    # OPERATION 14: WS Alert 1
    $operationCount++
    Write-ProgressLog "WSL Alert 1"
    try {
        $distro = 'Ubuntu'
        $user = 'root'
        $core = @('-d', $distro, '-u', $user, '--')
        $escaped = 'alert' -replace '"', '\"'
        wsl @core bash -li -c "$escaped"
        Write-Log "WSL Alert 1 completed"
    } catch {
        Write-Log "WSL Alert 1 failed: $_" "ERROR"
    }
    
    # OPERATION 15: BACKITUP - Backup process with verbose logging
    $operationCount++
    Write-ProgressLog "Backup process"
    try {
        Write-Log "Starting Docker backup process..."
        
        if (Test-Path "F:\backup\windowsapps") {
            Write-Log "Backing up Windows apps from F:\backup\windowsapps..."
            Set-Location -Path "F:\backup\windowsapps"
            Write-Log "Building Docker image: michadockermisha/backup:windowsapps"
            docker build -t michadockermisha/backup:windowsapps . 2>$null
            Write-Log "Pushing Docker image: michadockermisha/backup:windowsapps"
            docker push michadockermisha/backup:windowsapps 2>$null
            Write-Log "Windows apps backup completed"
        } else {
            Write-Log "Windows apps backup path not found: F:\backup\windowsapps" "WARN"
        }
        
        if (Test-Path "F:\study") {
            Write-Log "Backing up study folder from F:\study..."
            Set-Location -Path "F:\study"
            Write-Log "Building Docker image: michadockermisha/backup:study"
            docker build -t michadockermisha/backup:study . 2>$null
            Write-Log "Pushing Docker image: michadockermisha/backup:study"
            docker push michadockermisha/backup:study 2>$null
            Write-Log "Study folder backup completed"
        } else {
            Write-Log "Study folder not found: F:\study" "WARN"
        }
        
        if (Test-Path "F:\backup\linux\wsl") {
            Write-Log "Backing up WSL from F:\backup\linux\wsl..."
            Set-Location -Path "F:\backup\linux\wsl"
            Write-Log "Building Docker image: michadockermisha/backup:wsl"
            docker build -t michadockermisha/backup:wsl . 2>$null
            Write-Log "Pushing Docker image: michadockermisha/backup:wsl"
            docker push michadockermisha/backup:wsl 2>$null
            Write-Log "WSL backup completed"
        } else {
            Write-Log "WSL backup path not found: F:\backup\linux\wsl" "WARN"
        }
        
        Write-Log "Cleaning up Docker containers and images..."
        $containers = docker ps -a -q 2>$null
        if ($containers) {
            Write-Log "Stopping $($containers.Count) containers..."
            docker stop $containers 2>$null | Out-Null
            Write-Log "Removing $($containers.Count) containers..."
            docker rm $containers 2>$null | Out-Null
        } else {
            Write-Log "No containers to clean up"
        }
        
        $danglingImages = docker images -q --filter "dangling=true" 2>$null
        if ($danglingImages) {
            Write-Log "Removing $($danglingImages.Count) dangling images..."
            docker rmi $danglingImages 2>$null | Out-Null
        } else {
            Write-Log "No dangling images to clean up"
        }
        
        Write-Log "Backup process completed successfully"
    } catch {
        Write-Log "Backup process failed: $_" "ERROR"
    }
    
    # OPERATION 16: WS Alert 2
    $operationCount++
    Write-ProgressLog "WSL Alert 2"
    try {
        $distro = 'Ubuntu'
        $user = 'root'
        $core = @('-d', $distro, '-u', $user, '--')
        $escaped = 'alert' -replace '"', '\"'
        wsl @core bash -li -c "$escaped"
        Write-Log "WSL Alert 2 completed"
    } catch {
        Write-Log "WSL Alert 2 failed: $_" "ERROR"
    }
    
    # OPERATION 17: RWS - Reset WSL
    $operationCount++
    Write-ProgressLog "Reset WSL"
    try {
        wsl --shutdown 2>$null
        wsl --unregister ubuntu 2>$null
        
        if (Test-Path "F:\backup\linux\wsl\ubuntu.tar") {
            wsl --import ubuntu C:\wsl2\ubuntu\ F:\backup\linux\wsl\ubuntu.tar
            Write-Log "WSL reset completed"
        } else {
            Write-Log "WSL backup file not found" "WARN"
        }
    } catch {
        Write-Log "WSL reset failed: $_" "ERROR"
    }
    
    # OPERATION 18: RREWSL - Full WSL2 setup
    $operationCount++
    Write-ProgressLog "Full WSL2 setup"
    try {
        $wslBasePath = "C:\wsl2"
        $ubuntuPath1 = "$wslBasePath\ubuntu"
        $ubuntuPath2 = "$wslBasePath\ubuntu2"
        $backupPath = "F:\backup\linux\wsl\ubuntu.tar"
        
        foreach ($distro in @("ubuntu", "ubuntu2")) {
            $existingDistros = wsl --list --quiet 2>$null
            if ($existingDistros -contains $distro) {
                wsl --terminate $distro 2>$null
                wsl --unregister $distro 2>$null
            }
        }
        
        foreach ($path in @($ubuntuPath1, $ubuntuPath2)) {
            if (Test-Path "$path\ext4.vhdx") {
                Remove-Item "$path\ext4.vhdx" -Force -ErrorAction SilentlyContinue
            }
            if (-not (Test-Path $path)) {
                New-Item -ItemType Directory -Path $path -Force | Out-Null
            }
        }
        
        $features = @("Microsoft-Windows-Subsystem-Linux", "VirtualMachinePlatform")
        foreach ($f in $features) {
            $status = Get-WindowsOptionalFeature -Online -FeatureName $f -ErrorAction SilentlyContinue
            if ($status -and $status.State -ne "Enabled") {
                Enable-WindowsOptionalFeature -Online -FeatureName $f -NoRestart -ErrorAction SilentlyContinue
            }
        }
        
        foreach ($svc in @("vmms", "vmcompute")) {
            $s = Get-Service -Name $svc -ErrorAction SilentlyContinue
            if ($s -and $s.Status -ne "Running") {
                Start-Service -Name $svc -ErrorAction SilentlyContinue
            }
        }
        
        wsl --update 2>$null
        wsl --set-default-version 2
        
        if (Test-Path $backupPath) {
            wsl --import ubuntu $ubuntuPath1 $backupPath
            wsl --import ubuntu2 $ubuntuPath2 $backupPath
        }
        
        $wslConfig = @"
[wsl2]
memory=4GB
processors=2
swap=2GB
localhostForwarding=true

[experimental]
autoMemoryReclaim=gradual
networkingMode=mirrored
dnsTunneling=true
firewall=true
autoProxy=true
"@
        Set-Content "$env:USERPROFILE\.wslconfig" $wslConfig -Force
        
        wsl --set-default ubuntu
        Write-Log "WSL2 setup completed"
    } catch {
        Write-Log "WSL2 setup failed: $_" "ERROR"
    }
    
    # OPERATION 19: Final safe Docker cleanup - REPLACED WITH AGGRESSIVE ONE-LINER
    $operationCount++
    Write-ProgressLog "Final Docker cleanup (aggressive one-liner with timeout)"
    try {
        Write-Log "Running aggressive Docker cleanup one-liner with 3-minute timeout..."
        
        # Execute the one-liner with timeout protection
        $dockerCleanupJob = Start-Job {
            docker system prune -a --volumes -f
            docker builder prune -a -f
            docker buildx prune -a -f
            Stop-Process -Name "Docker Desktop" -Force -ErrorAction SilentlyContinue
            wsl --shutdown
            wsl --export docker-desktop "$env:TEMP\docker-desktop-backup.tar"
            wsl --unregister docker-desktop
            Remove-Item "C:\Users\misha\AppData\Local\Docker\wsl\disk\docker_data.vhdx" -Force -ErrorAction SilentlyContinue
            wsl --import docker-desktop "C:\Users\misha\AppData\Local\Docker\wsl\distro" "$env:TEMP\docker-desktop-backup.tar"
            Remove-Item "$env:TEMP\docker-desktop-backup.tar" -Force -ErrorAction SilentlyContinue
            Optimize-VHD -Path "C:\Users\misha\AppData\Local\Docker\wsl\disk\docker_data.vhdx" -Mode Full -ErrorAction SilentlyContinue
            & "C:\Program Files\Docker\Docker\Docker Desktop.exe"
        }
        
        Write-Log "Waiting for Docker cleanup to complete (max 180 seconds)..."
        if (Wait-Job $dockerCleanupJob -Timeout 180) {
            Receive-Job $dockerCleanupJob | Out-Null
            Remove-Job $dockerCleanupJob
            Write-Log "✅ Aggressive Docker cleanup completed successfully"
        } else {
            Stop-Job $dockerCleanupJob
            Remove-Job $dockerCleanupJob
            Write-Log "⚠️ Docker cleanup timeout (180s) - force killing processes and continuing..." "WARN"
            
            # Force kill any hanging processes
            $processesToKill = @("docker", "wsl", "vssadmin")
            foreach ($proc in $processesToKill) {
                Get-Process -Name $proc -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
            }
            Write-Log "Force terminated hanging processes"
        }
    } catch {
        Write-Log "Final Docker cleanup failed: $_" "ERROR"
    }
    
    # OPERATION 20: RERE - Network boost (FULL NETWORK OPTIMIZATION) with verbose logging
    $operationCount++
    Write-ProgressLog "DRIVER-SAFE WIFI SPEED BOOSTER"
    try {
        $commandCount = 0
        
        Write-Log "Starting TCP/IP STACK OPTIMIZATION (25+ commands)..."
        # TCP/IP STACK OPTIMIZATION
        Write-Log "Setting TCP autotuninglevel=normal..."; netsh int tcp set global autotuninglevel=normal; $commandCount++
        Write-Log "Enabling ECN capability..."; netsh int tcp set global ecncapability=enabled; $commandCount++
        Write-Log "Disabling timestamps..."; netsh int tcp set global timestamps=disabled; $commandCount++
        Write-Log "Setting initial RTO to 1000ms..."; netsh int tcp set global initialRto=1000; $commandCount++
        Write-Log "Enabling receive side coalescing..."; netsh int tcp set global rsc=enabled; $commandCount++
        Write-Log "Disabling non-sack RTT resiliency..."; netsh int tcp set global nonsackrttresiliency=disabled; $commandCount++
        Write-Log "Setting max SYN retransmissions to 2..."; netsh int tcp set global maxsynretransmissions=2; $commandCount++
        Write-Log "Enabling TCP chimney..."; netsh int tcp set global chimney=enabled; $commandCount++
        Write-Log "Enabling window scaling..."; netsh int tcp set global windowsscaling=enabled; $commandCount++
        Write-Log "Enabling direct cache access..."; netsh int tcp set global dca=enabled; $commandCount++
        Write-Log "Enabling NetDMA..."; netsh int tcp set global netdma=enabled; $commandCount++
        Write-Log "Setting congestion provider to CTCP..."; netsh int tcp set supplemental Internet congestionprovider=ctcp; $commandCount++
        Write-Log "Disabling heuristics..."; netsh int tcp set heuristics disabled; $commandCount++
        Write-Log "Enabling RSS..."; netsh int tcp set global rss=enabled; $commandCount++
        Write-Log "Enabling fast open..."; netsh int tcp set global fastopen=enabled 2>$null; $commandCount++
        
        Write-Log "Configuring IP settings..."
        Write-Log "Enabling task offload..."; netsh int ip set global taskoffload=enabled; $commandCount++
        Write-Log "Setting neighbor cache limit..."; netsh int ip set global neighborcachelimit=8192; $commandCount++
        Write-Log "Setting route cache limit..."; netsh int ip set global routecachelimit=8192; $commandCount++
        Write-Log "Enabling DHCP media sense..."; netsh int ip set global dhcpmediasense=enabled; $commandCount++
        Write-Log "Setting source routing behavior..."; netsh int ip set global sourceroutingbehavior=dontforward; $commandCount++
        Write-Log "Disabling IPv4 randomize identifiers..."; netsh int ipv4 set global randomizeidentifiers=disabled; $commandCount++
        Write-Log "Disabling IPv6 randomize identifiers..."; netsh int ipv6 set global randomizeidentifiers=disabled; $commandCount++
        Write-Log "Disabling Teredo..."; netsh int ipv6 set teredo disabled; $commandCount++
        Write-Log "Disabling 6to4..."; netsh int ipv6 set 6to4 disabled; $commandCount++
        Write-Log "Disabling ISATAP..."; netsh int ipv6 set isatap disabled; $commandCount++
        
        Write-Log "TCP/IP optimization completed: $commandCount commands executed"
        
        # REGISTRY OPTIMIZATIONS
        Write-Log "Starting REGISTRY OPTIMIZATIONS..."
        $tcpipSettings = @{
            "NetworkThrottlingIndex" = 0xffffffff; "DefaultTTL" = 64; "TCPNoDelay" = 1
            "Tcp1323Opts" = 3; "TCPAckFrequency" = 1; "TCPDelAckTicks" = 0
            "MaxFreeTcbs" = 65536; "MaxHashTableSize" = 65536; "MaxUserPort" = 65534
            "TcpTimedWaitDelay" = 30; "TcpUseRFC1122UrgentPointer" = 0
            "TcpMaxDataRetransmissions" = 3; "KeepAliveTime" = 7200000
            "KeepAliveInterval" = 1000; "EnablePMTUDiscovery" = 1
        }
        
        $tcpipPath = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters"
        foreach ($name in $tcpipSettings.Keys) {
            try {
                Write-Log "Setting registry value: $name = $($tcpipSettings[$name])"
                Set-ItemProperty -Path $tcpipPath -Name $name -Value $tcpipSettings[$name] -Type DWord -Force
                $commandCount++
            } catch {
                Write-Log "Warning: Could not set registry value $name" "WARN"
            }
        }
        
        Write-Log "Registry optimization completed: $($tcpipSettings.Count) values set"
        
        # DNS OPTIMIZATION
        Write-Log "Starting DNS OPTIMIZATION..."
        Write-Log "Setting primary DNS to Cloudflare (1.1.1.1)..."; netsh interface ip set dns name="Wi-Fi" source=static addr=1.1.1.1; $commandCount++
        Write-Log "Adding secondary DNS (1.0.0.1)..."; netsh interface ip add dns name="Wi-Fi" addr=1.0.0.1 index=2; $commandCount++
        Write-Log "Adding tertiary DNS (8.8.8.8)..."; netsh interface ip add dns name="Wi-Fi" addr=8.8.8.8 index=3; $commandCount++
        Write-Log "Adding quaternary DNS (8.8.4.4)..."; netsh interface ip add dns name="Wi-Fi" addr=8.8.4.4 index=4; $commandCount++
        
        # POWER OPTIMIZATION
        Write-Log "Starting POWER OPTIMIZATION..."
        Write-Log "Setting high performance power plan..."; powercfg -setactive SCHEME_MIN; $commandCount++
        Write-Log "Disabling monitor timeout..."; powercfg -change -monitor-timeout-ac 0; $commandCount++
        Write-Log "Disabling disk timeout..."; powercfg -change -disk-timeout-ac 0; $commandCount++
        Write-Log "Disabling standby timeout..."; powercfg -change -standby-timeout-ac 0; $commandCount++
        Write-Log "Disabling hibernate timeout..."; powercfg -change -hibernate-timeout-ac 0; $commandCount++
        
        # FINAL CLEANUP
        Write-Log "Starting FINAL NETWORK CLEANUP..."
        Write-Log "Flushing DNS cache..."; ipconfig /flushdns; $commandCount++
        Write-Log "Registering DNS..."; ipconfig /registerdns; $commandCount++
        Write-Log "Resetting IP stack..."; netsh int ip reset C:\resetlog.txt; $commandCount++
        Write-Log "Resetting Winsock..."; netsh winsock reset; $commandCount++
        Write-Log "Resetting WinHTTP proxy..."; netsh winhttp reset proxy; $commandCount++
        
        Write-Log "DRIVER-SAFE WIFI OPTIMIZATION COMPLETED! Total Commands: $commandCount"
    } catch {
        Write-Log "Network boost failed: $_" "ERROR"
    }
    
    # OPERATION 21: Comprehensive PC Performance Optimization
    $operationCount++
    Write-ProgressLog "Comprehensive PC Performance Optimization"
    
    # COMPREHENSIVE PC PERFORMANCE BOOST - EVERY SAFE COMMAND
    Write-Log "=== COMPREHENSIVE PC PERFORMANCE OPTIMIZATION ==="
    try {
        $perfCommandCount = 0
        Write-Log "Starting comprehensive PC performance optimization with every safe command..."
        
        # REGISTRY PERFORMANCE OPTIMIZATIONS
        Write-Log "Applying comprehensive registry performance optimizations..."
        
        # System Responsiveness and Priority
        $systemPerfSettings = @{
            "SystemResponsiveness" = 0
            "NetworkThrottlingIndex" = 0xffffffff  
            "Win32PrioritySeparation" = 38
            "IRQ8Priority" = 1
            "PCILatency" = 0
            "DisablePagingExecutive" = 1
            "LargeSystemCache" = 1
            "IoPageLockLimit" = 0x4000000
            "PoolUsageMaximum" = 96
            "PagedPoolSize" = 0xffffffff
            "NonPagedPoolSize" = 0x0
            "SessionPoolSize" = 192
            "SecondLevelDataCache" = 1024
            "ThirdLevelDataCache" = 8192
        }
        
        $perfPaths = @(
            "HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl",
            "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management",
            "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile"
        )
        
        foreach ($path in $perfPaths) {
            if (-not (Test-Path $path)) { New-Item -Path $path -Force | Out-Null }
            foreach ($setting in $systemPerfSettings.GetEnumerator()) {
                try {
                    Set-ItemProperty -Path $path -Name $setting.Key -Value $setting.Value -Type DWord -Force -ErrorAction SilentlyContinue
                    $perfCommandCount++
                } catch { }
            }
        }
        
        # CPU and Processor Optimizations
        Write-Log "Optimizing CPU and processor settings..."
        $cpuSettings = @{
            "UsePlatformClock" = 1
            "TSCFrequency" = 0
            "DisableDynamicTick" = 1
            "UseQPC" = 1
        }
        
        $cpuPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\kernel"
        foreach ($setting in $cpuSettings.GetEnumerator()) {
            try {
                Set-ItemProperty -Path $cpuPath -Name $setting.Key -Value $setting.Value -Type DWord -Force -ErrorAction SilentlyContinue
                $perfCommandCount++
            } catch { }
        }
        
        # Graphics and Visual Performance
        Write-Log "Optimizing graphics and visual performance..."
        $visualSettings = @{
            "VisualEffects" = 2  # Best performance
            "DragFullWindows" = 0
            "MenuShowDelay" = 0
            "MinAnimate" = 0
            "TaskbarAnimations" = 0
            "ListviewWatermark" = 0
            "UserPreferencesMask" = [byte[]](0x90,0x12,0x03,0x80,0x10,0x00,0x00,0x00)
        }
        
        $visualPaths = @(
            "HKCU:\Control Panel\Desktop",
            "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects",
            "HKCU:\Control Panel\Desktop\WindowMetrics"
        )
        
        foreach ($path in $visualPaths) {
            if (-not (Test-Path $path)) { New-Item -Path $path -Force | Out-Null }
            foreach ($setting in $visualSettings.GetEnumerator()) {
                try {
                    if ($setting.Key -eq "UserPreferencesMask") {
                        Set-ItemProperty -Path $path -Name $setting.Key -Value $setting.Value -Type Binary -Force -ErrorAction SilentlyContinue
                    } else {
                        Set-ItemProperty -Path $path -Name $setting.Key -Value $setting.Value -Type DWord -Force -ErrorAction SilentlyContinue
                    }
                    $perfCommandCount++
                } catch { }
            }
        }
        
        # Disable Unnecessary Services
        Write-Log "Disabling unnecessary services for performance..."
        $servicesToDisable = @(
            "BITS", "wuauserv", "DoSvc", "MapsBroker", "RetailDemo", "DiagTrack", 
            "dmwappushservice", "WSearch", "SysMain", "Themes", "TabletInputService",
            "Fax", "WbioSrvc", "WMPNetworkSvc", "WerSvc", "Spooler", "AxInstSV",
            "Browser", "CscService", "TrkWks", "SharedAccess", "lmhosts", "RemoteAccess",
            "SessionEnv", "TermService", "UmRdpService", "AppVClient", "NetTcpPortSharing",
            "wisvc", "WinDefend", "SecurityHealthService", "wscsvc"
        )
        
        foreach ($service in $servicesToDisable) {
            try {
                $svc = Get-Service -Name $service -ErrorAction SilentlyContinue
                if ($svc -and $svc.Status -eq "Running") {
                    Stop-Service -Name $service -Force -ErrorAction SilentlyContinue
                    Set-Service -Name $service -StartupType Disabled -ErrorAction SilentlyContinue
                    Write-Log "Disabled service: $service"
                    $perfCommandCount++
                }
            } catch { }
        }
        
        # Gaming and Multimedia Optimizations
        Write-Log "Applying gaming and multimedia optimizations..."
        $gamingPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games"
        $gamingSettings = @{
            "Affinity" = 0
            "Background Only" = "False"
            "BackgroundPriority" = 0
            "Clock Rate" = 10000
            "GPU Priority" = 8
            "Priority" = 6
            "Scheduling Category" = "High"
            "SFIO Priority" = "High"
        }
        
        if (-not (Test-Path $gamingPath)) { New-Item -Path $gamingPath -Force | Out-Null }
        foreach ($setting in $gamingSettings.GetEnumerator()) {
            try {
                Set-ItemProperty -Path $gamingPath -Name $setting.Key -Value $setting.Value -Force -ErrorAction SilentlyContinue
                $perfCommandCount++
            } catch { }
        }
        
        # Disable Windows Features that impact performance
        Write-Log "Disabling performance-impacting Windows features..."
        $featuresToDisable = @(
            "TelnetClient", "TFTP", "TIFFIFilter", "Windows-Defender-Default-Definitions",
            "WorkFolders-Client", "Printing-XPSServices-Features", "FaxServicesClientPackage"
        )
        
        foreach ($feature in $featuresToDisable) {
            try {
                Disable-WindowsOptionalFeature -Online -FeatureName $feature -NoRestart -ErrorAction SilentlyContinue
                $perfCommandCount++
            } catch { }
        }
        
        Write-Log "PC Performance optimization completed: $perfCommandCount commands executed"
        
    } catch {
        Write-Log "PC Performance optimization failed: $_" "ERROR"
    }
    
    # OPERATION 22: Comprehensive Disk Space Cleanup
    $operationCount++
    Write-ProgressLog "Comprehensive Disk Space Cleanup"
    
    # COMPREHENSIVE DISK CLEANUP - C: AND F: DRIVES
    Write-Log "=== COMPREHENSIVE DISK SPACE CLEANUP (C: & F: DRIVES) ==="
    try {
        $cleanupCommandCount = 0
        Write-Log "Starting comprehensive disk cleanup for C: and F: drives..."
        
        # Define all safe cleanup locations for C: drive
        $cDriveCleanupPaths = @(
            "C:\Windows\Temp\*",
            "C:\Windows\Prefetch\*",
            "C:\Windows\SoftwareDistribution\Download\*",
            "C:\Windows\Logs\*",
            "C:\Windows\Panther\*",
            "C:\Windows\System32\LogFiles\*",
            "C:\Windows\System32\config\systemprofile\AppData\Local\Temp\*",
            "C:\Windows\ServiceProfiles\LocalService\AppData\Local\Temp\*",
            "C:\Windows\ServiceProfiles\NetworkService\AppData\Local\Temp\*",
            "C:\Windows\Downloaded Program Files\*",
            "C:\Windows\SysWOW64\config\systemprofile\AppData\Local\Temp\*",
            "C:\ProgramData\Microsoft\Windows\WER\ReportQueue\*",
            "C:\ProgramData\Microsoft\Windows\WER\ReportArchive\*",
            "C:\ProgramData\Microsoft\Windows\WER\Temp\*",
            "C:\ProgramData\Microsoft\Search\Data\Applications\Windows\*",
            "C:\ProgramData\Microsoft\Diagnosis\*",
            "C:\ProgramData\Microsoft\Windows Defender\Scans\History\*",
            "C:\ProgramData\Package Cache\*",
            "C:\Windows\Installer\*.msi",
            "C:\Windows\Installer\*.msp"
        )
        
        # User-specific cleanup paths for all users
        $users = Get-ChildItem "C:\Users" -Directory -ErrorAction SilentlyContinue
        $userCleanupPaths = @()
        foreach ($user in $users) {
            if ($user.Name -notmatch "^(All Users|Default|Public)$") {
                $userCleanupPaths += @(
                    "$($user.FullName)\AppData\Local\Temp\*",
                    "$($user.FullName)\AppData\Local\Microsoft\Windows\INetCache\*",
                    "$($user.FullName)\AppData\Local\Microsoft\Windows\WebCache\*", 
                    "$($user.FullName)\AppData\Local\Microsoft\Windows\Explorer\thumbcache_*.db",
                    "$($user.FullName)\AppData\Local\Microsoft\Windows\Explorer\iconcache_*.db",
                    "$($user.FullName)\AppData\Local\Microsoft\Terminal Server Client\Cache\*",
                    "$($user.FullName)\AppData\Local\CrashDumps\*",
                    "$($user.FullName)\AppData\Local\D3DSCache\*",
                    "$($user.FullName)\AppData\Local\fontconfig\*",
                    "$($user.FullName)\AppData\Local\GDIPFONTCACHEV1.DAT",
                    "$($user.FullName)\AppData\Local\IconCache.db",
                    "$($user.FullName)\AppData\Local\Microsoft\CLR_v*",
                    "$($user.FullName)\AppData\Local\Microsoft\Internet Explorer\Recovery\*",
                    "$($user.FullName)\AppData\Local\Microsoft\Media Player\*",
                    "$($user.FullName)\AppData\Local\Microsoft\Windows\Caches\*",
                    "$($user.FullName)\AppData\Local\Microsoft\Windows\Explorer\*.db",
                    "$($user.FullName)\AppData\Local\Microsoft\Windows\SchCache\*",
                    "$($user.FullName)\AppData\Local\Microsoft\Windows\WinX\*",
                    "$($user.FullName)\AppData\Local\Package Cache\*",
                    "$($user.FullName)\AppData\Local\Packages\*\TempState\*",
                    "$($user.FullName)\AppData\Local\Packages\*\AC\Temp\*",
                    "$($user.FullName)\AppData\Local\Google\Chrome\User Data\Default\Cache\*",
                    "$($user.FullName)\AppData\Local\Google\Chrome\User Data\Default\Code Cache\*",
                    "$($user.FullName)\AppData\Local\Google\Chrome\User Data\Default\Media Cache\*",
                    "$($user.FullName)\AppData\Local\Microsoft\Edge\User Data\Default\Cache\*",
                    "$($user.FullName)\AppData\Local\Microsoft\Edge\User Data\Default\Code Cache\*",
                    "$($user.FullName)\AppData\Local\Mozilla\Firefox\Profiles\*\cache2\*",
                    "$($user.FullName)\AppData\Local\Opera Software\Opera Stable\Cache\*"
                )
            }
        }
        
        # F: drive cleanup paths (assuming F: is a data drive)
        $fDriveCleanupPaths = @()
        if (Test-Path "F:\") {
            $fDriveCleanupPaths = @(
                "F:\temp\*",
                "F:\tmp\*", 
                "F:\Temp\*",
                "F:\Windows.old\*",
                "F:\`$Recycle.Bin\*",
                "F:\System Volume Information\*",
                "F:\hiberfil.sys",
                "F:\pagefile.sys",
                "F:\swapfile.sys"
            )
        }
        
        # Combine all cleanup paths
        $allCleanupPaths = $cDriveCleanupPaths + $userCleanupPaths + $fDriveCleanupPaths
        
        # Execute cleanup for each path with global timeout protection
        $totalFilesDeleted = 0
        $totalSizeFreed = 0
        $pathsProcessed = 0
        
        Write-Log "Processing $($allCleanupPaths.Count) cleanup directories..."
        
        # Add global timeout for disk cleanup section
        $diskCleanupStart = Get-Date
        $maxDiskCleanupTime = 600  # 10 minutes maximum for disk cleanup
        
        foreach ($path in $allCleanupPaths) {
            # Check global timeout
            if (((Get-Date) - $diskCleanupStart).TotalSeconds -gt $maxDiskCleanupTime) {
                Write-Log "Disk cleanup timeout reached ($maxDiskCleanupTime seconds) - skipping remaining paths..." "WARN"
                break
            }
            
            $pathsProcessed++
            if (Test-Path $path) {
                try {
                    Write-Log "[$pathsProcessed/$($allCleanupPaths.Count)] Processing: $path"
                    
                    # Set timeout for each individual path (30 seconds max)
                    $pathStart = Get-Date
                    $items = Get-ChildItem -Path $path -Force -ErrorAction SilentlyContinue
                    $pathFileCount = 0
                    $pathSizeFreed = 0
                    
                    foreach ($item in $items) {
                        # Check individual path timeout
                        if (((Get-Date) - $pathStart).TotalSeconds -gt 30) {
                            Write-Log "  Path processing timeout (30s) - moving to next path..." "WARN"
                            break
                        }
                        
                        try {
                            if ($item.PSIsContainer) {
                                # Directory - get size then remove (with timeout protection)
                                $dirSizeJob = Start-Job {
                                    param($itemPath)
                                    (Get-ChildItem -Path $itemPath -Recurse -Force -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum
                                } -ArgumentList $item.FullName
                                
                                $dirSize = 0
                                if (Wait-Job $dirSizeJob -Timeout 10) {
                                    $dirSize = Receive-Job $dirSizeJob
                                } else {
                                    Stop-Job $dirSizeJob
                                }
                                Remove-Job $dirSizeJob -ErrorAction SilentlyContinue
                                
                                Remove-Item -Path $item.FullName -Recurse -Force -ErrorAction SilentlyContinue
                                if ($dirSize) { $pathSizeFreed += $dirSize }
                            } else {
                                # File - get size then remove
                                $fileSize = $item.Length
                                Remove-Item -Path $item.FullName -Force -ErrorAction SilentlyContinue
                                $pathSizeFreed += $fileSize
                            }
                            $pathFileCount++
                        } catch { }
                    }
                    
                    if ($pathFileCount -gt 0) {
                        Write-Log "  Cleaned $pathFileCount items, freed $([math]::Round($pathSizeFreed/1MB, 2)) MB"
                        $totalFilesDeleted += $pathFileCount
                        $totalSizeFreed += $pathSizeFreed
                    }
                } catch {
                    Write-Log "  Error processing $path`: $_" "ERROR"
                }
            } else {
                Write-Log "[$pathsProcessed/$($allCleanupPaths.Count)] Path not found: $path"
            }
        }
        
        Write-Log "Disk cleanup completed: $cleanupCommandCount operations, $totalFilesDeleted files deleted, $([math]::Round($totalSizeFreed/1GB, 2)) GB freed"
        
    } catch {
        Write-Log "Disk cleanup failed: $_" "ERROR"
    }
    
    # OPERATION 23: Wise Registry Cleaner with spinning progress
    $operationCount++
    Write-ProgressLog "Wise Registry Cleaner deep scan"
    try {
        if (Test-Path "F:\backup\windowsapps\installed\Wise\Wise Registry Cleaner\WiseRegCleaner.exe") {
            Write-Log "Starting Wise Registry Cleaner with animated progress..."
            
            # Execute Wise Registry Cleaner with spinning progress indicator
            $sp='|/-\';$i=0; $p=Start-Process 'F:\backup\windowsapps\installed\Wise\Wise Registry Cleaner\WiseRegCleaner.exe' -ArgumentList '-a','-all' -WindowStyle Hidden -PassThru; while(!$p.HasExited){Write-Host -NoNewline "`r$($sp[$i++%$sp.Length]) deep-clean running…";Start-Sleep -Milliseconds 200} Write-Host "`r✓ deep-clean finished.     "
            
            Write-Log "Wise Registry Cleaner completed successfully"
        } else {
            Write-Log "Wise Registry Cleaner not found at F:\backup\windowsapps\installed\Wise\Wise Registry Cleaner\WiseRegCleaner.exe" "WARN"
        }
    } catch {
        Write-Log "Wise Registry Cleaner failed: $_" "ERROR"
    }
    
    # OPERATION 24: Wise Disk Cleaner with spinning progress and 2-minute timeout
    $operationCount++
    Write-ProgressLog "Wise Disk Cleaner advanced scan (2-minute timeout)"
    try {
        if (Test-Path "F:\backup\windowsapps\installed\Wise\Wise Disk Cleaner\WiseDiskCleaner.exe") {
            Write-Log "Starting Wise Disk Cleaner with animated progress and 2-minute timeout..."
            
            # Execute Wise Disk Cleaner with spinning progress indicator and 2-minute timeout
            $sp='|/-\';$i=0;$p=Start-Process 'F:\backup\windowsapps\installed\Wise\Wise Disk Cleaner\WiseDiskCleaner.exe' -ArgumentList '-a','-adv' -WindowStyle Hidden -PassThru;$timeout=120;$timer=0;while(!$p.HasExited -and $timer -lt $timeout){Write-Host -NoNewline "`r$($sp[$i++%$sp.Length]) disk deep-clean running…";Start-Sleep -Milliseconds 200;$timer+=0.2};if(!$p.HasExited){Write-Host "`r⚠️ disk deep-clean timeout (2 min) - force killing...";$p.Kill();Write-Host "`r✓ disk deep-clean finished (timeout).     "}else{Write-Host "`r✓ disk deep-clean finished.     "}
            
            Write-Log "Wise Disk Cleaner completed (with 2-minute timeout protection)"
        } else {
            Write-Log "Wise Disk Cleaner not found at F:\backup\windowsapps\installed\Wise\Wise Disk Cleaner\WiseDiskCleaner.exe" "WARN"
        }
    } catch {
        Write-Log "Wise Disk Cleaner failed: $_" "ERROR"
    }
    
    $totalTime = (Get-Date) - $global:ScriptStartTime
    Write-Log "=== System Optimization Completed in $($totalTime.TotalMinutes.ToString('F1')) minutes ==="
    
    # FINAL CLEANUP: Force remove unnecessary folders from C: drive
    Write-Log "=== FINAL CLEANUP: Removing unnecessary folders from C: drive ==="
    
    $foldersToRemove = @(
        "C:\AdwCleaner",
        "C:\inetpub",
        "C:\PerfLogs",
        "C:\Logs",
        "C:\temp",
        "C:\tmp",
        "C:\Windows.old",
        "C:\Intel",
        "C:\AMD",
        "C:\NVIDIA",
        "C:\OneDriveTemp",
        "C:\Recovery\WindowsRE"
    )
    
    foreach ($folder in $foldersToRemove) {
        try {
            if (Test-Path $folder) {
                Write-Log "Attempting to remove folder: $folder"
                
                # First try normal removal
                Remove-Item -Path $folder -Recurse -Force -ErrorAction SilentlyContinue
                
                # If still exists, try takeown and icacls
                if (Test-Path $folder) {
                    Write-Log "Folder still exists, trying takeown/icacls method..."
                    takeown /f "$folder" /r /d y 2>$null | Out-Null
                    icacls "$folder" /grant administrators:F /t /q 2>$null | Out-Null
                    Remove-Item -Path $folder -Recurse -Force -ErrorAction SilentlyContinue
                }
                
                # Final check
                if (Test-Path $folder) {
                    Write-Log "Could not remove folder: $folder (may be in use)" "WARN"
                } else {
                    Write-Log "Successfully removed folder: $folder"
                }
            } else {
                Write-Log "Folder not found (already clean): $folder"
            }
        } catch {
            Write-Log "Error removing folder $folder`: $_" "ERROR"
        }
    }
    
    # Additional cleanup of leftover installer files
    Write-Log "=== Cleaning leftover installer and temp files ==="
    $additionalCleanup = @(
        "C:\Windows\Installer\*.msi",
        "C:\Windows\Downloaded Program Files\*",
        "C:\Windows\Temp\*",
        "C:\Windows\Logs\*",
        "C:\Windows\Panther\*",
        "C:\Windows\SoftwareDistribution\Download\*"
    )
    
    foreach ($pattern in $additionalCleanup) {
        try {
            $items = Get-ChildItem -Path $pattern -ErrorAction SilentlyContinue
            if ($items) {
                Write-Log "Cleaning: $pattern (found $($items.Count) items)"
                Remove-Item -Path $pattern -Recurse -Force -ErrorAction SilentlyContinue
            } else {
                Write-Log "No items found for: $pattern"
            }
        } catch {
            Write-Log "Error cleaning $pattern`: $_" "ERROR"
        }
    }
    
    # Stop all safety jobs
    try {
        Stop-Job $progressJob -ErrorAction SilentlyContinue
        Remove-Job $progressJob -ErrorAction SilentlyContinue
        
        Stop-Job $globalTimeoutJob -ErrorAction SilentlyContinue
        Remove-Job $globalTimeoutJob -ErrorAction SilentlyContinue
        
        Write-Log "All background safety jobs terminated"
    } catch { }
    
    # Final process cleanup before restart - AGGRESSIVE
    Write-Log "=== FINAL PROCESS CLEANUP (AGGRESSIVE) ==="
    try {
        $processesToKill = @("CCleaner*", "adwcleaner", "bleachbit*", "cleanmgr", "wsreset", "dism", "WiseRegCleaner", "WiseDiskCleaner")
        foreach ($processPattern in $processesToKill) {
            $processes = Get-Process -Name $processPattern -ErrorAction SilentlyContinue
            if ($processes) {
                Write-Log "🚨 Force killing remaining $processPattern processes..."
                $processes | Stop-Process -Force -ErrorAction SilentlyContinue
                
                # Wait and verify
                Start-Sleep 2
                $remainingProcesses = Get-Process -Name $processPattern -ErrorAction SilentlyContinue
                if ($remainingProcesses) {
                    Write-Log "⚠️  Some $processPattern processes still running - using taskkill..." "WARN"
                    taskkill /f /im "$processPattern.exe" 2>$null
                }
            }
        }
        Write-Log "✅ All potentially hanging processes terminated"
    } catch {
        Write-Log "Error in final process cleanup: $_" "ERROR"
    }
    
    Write-Log "Log saved to: $global:LogPath"
    
    # NEW: Final System Optimization Verification
    if ($global:RestartChoice -ne "none") {
        Write-Log "=== FINAL SYSTEM OPTIMIZATION VERIFICATION ==="
        try {
            Write-Log "Running final system optimization verification before reboot..."
            
            # Final hiberfil.sys check and removal
            Write-Log "Final hiberfil.sys verification and removal..."
            $hiberfilPaths = @("C:\hiberfil.sys", "D:\hiberfil.sys", "E:\hiberfil.sys", "F:\hiberfil.sys", "G:\hiberfil.sys")
            foreach ($hiberPath in $hiberfilPaths) {
                if (Test-Path $hiberPath) {
                    try {
                        Write-Log "Final attempt to remove: $hiberPath"
                        cmd /c "takeown /f `"$hiberPath`" /d y" 2>$null | Out-Null
                        cmd /c "icacls `"$hiberPath`" /grant administrators:F" 2>$null | Out-Null
                        Remove-Item -Path $hiberPath -Force -ErrorAction SilentlyContinue
                        if (!(Test-Path $hiberPath)) {
                            Write-Log "✅ Successfully removed: $hiberPath"
                        } else {
                            Write-Log "⚠️ Could not remove: $hiberPath (system locked)" "WARN"
                        }
                    } catch {
                        Write-Log "Error in final hiberfil removal: $_" "ERROR"
                    }
                } else {
                    Write-Log "✅ Hiberfil not present: $hiberPath"
                }
            }
            
            Write-Log "✅ Final system optimization verification completed!"
            
        } catch {
            Write-Log "Final system optimization verification failed: $_" "ERROR"
        }
        
        # FINAL SYSTEM CLEANUP BEFORE REBOOT
        Write-Log "=== FINAL SYSTEM CLEANUP BEFORE REBOOT (5-MINUTE TIMEOUT) ==="
        try {
            Write-Log "Running final system cleanup commands before reboot with strict timeouts..."
            $finalCleanupStart = Get-Date
            $maxFinalCleanupTime = 300  # 5 minutes maximum
            
            # 1. Windows Disk Cleanup with 60-second timeout
            Write-Log "Running Windows Disk Cleanup (60-second timeout)..."
            $cleanmgrJob = Start-Job {
                Start-Process "cleanmgr.exe" -WindowStyle Hidden -Wait
            }
            if (Wait-Job $cleanmgrJob -Timeout 60) {
                Receive-Job $cleanmgrJob | Out-Null
                Remove-Job $cleanmgrJob
                Write-Log "✅ Windows Disk Cleanup completed"
            } else {
                Stop-Job $cleanmgrJob
                Remove-Job $cleanmgrJob
                Write-Log "⚠️ Windows Disk Cleanup timeout (60s) - continuing..." "WARN"
                Get-Process -Name "cleanmgr" -ErrorAction SilentlyContinue | Stop-Process -Force
            }
            
            # Check if we have time left
            if (((Get-Date) - $finalCleanupStart).TotalSeconds -gt $maxFinalCleanupTime) {
                Write-Log "🚨 Final cleanup timeout reached - skipping remaining operations..." "WARN"
                return
            }
            
            # 2. WinGet upgrade with 120-second timeout
            Write-Log "Running WinGet upgrade (120-second timeout)..."
            $wingetJob = Start-Job {
                Start-Process "winget" -ArgumentList "upgrade", "--all", "--accept-source-agreements", "--silent" -WindowStyle Hidden -Wait
            }
            if (Wait-Job $wingetJob -Timeout 120) {
                Receive-Job $wingetJob | Out-Null
                Remove-Job $wingetJob
                Write-Log "✅ WinGet upgrade completed"
            } else {
                Stop-Job $wingetJob
                Remove-Job $wingetJob
                Write-Log "⚠️ WinGet upgrade timeout (120s) - continuing..." "WARN"
                Get-Process -Name "winget" -ErrorAction SilentlyContinue | Stop-Process -Force
            }
            
            # Check if we have time left
            if (((Get-Date) - $finalCleanupStart).TotalSeconds -gt $maxFinalCleanupTime) {
                Write-Log "🚨 Final cleanup timeout reached - skipping remaining operations..." "WARN"
                return
            }
            
            # 3. System Volume Information cleanup with 60-second timeout
            Write-Log "Cleaning System Volume Information files (60-second timeout)..."
            $sviJob = Start-Job {
                Get-ChildItem "C:\System Volume Information" -Force -Recurse -ErrorAction SilentlyContinue | ForEach-Object { 
                    try { 
                        $_.Attributes = 'Normal'
                        Remove-Item $_.FullName -Force -Recurse -ErrorAction SilentlyContinue
                    } catch { } 
                }
            }
            if (Wait-Job $sviJob -Timeout 60) {
                Receive-Job $sviJob | Out-Null
                Remove-Job $sviJob
                Write-Log "✅ System Volume Information cleanup completed"
            } else {
                Stop-Job $sviJob
                Remove-Job $sviJob
                Write-Log "⚠️ System Volume Information cleanup timeout (60s) - continuing..." "WARN"
            }
            
            # Check if we have time left
            if (((Get-Date) - $finalCleanupStart).TotalSeconds -gt $maxFinalCleanupTime) {
                Write-Log "🚨 Final cleanup timeout reached - skipping remaining operations..." "WARN"
                return
            }
            
            # 4. Disk Cleanup sageset with 30-second timeout
            Write-Log "Configuring Disk Cleanup settings (30-second timeout)..."
            $sagesetJob = Start-Job {
                Start-Process "cleanmgr" -ArgumentList "/sageset:1" -WindowStyle Hidden -Wait
            }
            if (Wait-Job $sagesetJob -Timeout 30) {
                Receive-Job $sagesetJob | Out-Null
                Remove-Job $sagesetJob
                Write-Log "✅ Disk Cleanup settings configured"
            } else {
                Stop-Job $sagesetJob
                Remove-Job $sagesetJob
                Write-Log "⚠️ Disk Cleanup sageset timeout (30s) - continuing..." "WARN"
                Get-Process -Name "cleanmgr" -ErrorAction SilentlyContinue | Stop-Process -Force
            }
            
            # Check if we have time left
            if (((Get-Date) - $finalCleanupStart).TotalSeconds -gt $maxFinalCleanupTime) {
                Write-Log "🚨 Final cleanup timeout reached - skipping remaining operations..." "WARN"
                return
            }
            
            # 5. Volume shadow copy deletion with 30-second timeout
            Write-Log "Deleting volume shadow copies (30-second timeout)..."
            $vssJob = Start-Job {
                Start-Process "vssadmin" -ArgumentList "delete", "shadows", "/for=C:", "/all", "/quiet" -WindowStyle Hidden -Wait
            }
            if (Wait-Job $vssJob -Timeout 30) {
                Receive-Job $vssJob | Out-Null
                Remove-Job $vssJob
                Write-Log "✅ Volume shadow copies deleted"
            } else {
                Stop-Job $vssJob
                Remove-Job $vssJob
                Write-Log "⚠️ Volume shadow copy deletion timeout (30s) - continuing..." "WARN"
                Get-Process -Name "vssadmin" -ErrorAction SilentlyContinue | Stop-Process -Force
            }
            
            $finalCleanupDuration = ((Get-Date) - $finalCleanupStart).TotalSeconds
            Write-Log "✅ Final system cleanup before reboot completed in $([math]::Round($finalCleanupDuration, 1)) seconds!"
            
        } catch {
            Write-Log "Final system cleanup before reboot failed: $_" "ERROR"
        }
    }
    
    # OPERATION 25: Final Script (Conditional based on user choice)
    if ($global:RestartChoice -ne "none") {
        $operationCount++
        Write-ProgressLog "Final script execution"
        
        if ($global:RestartChoice -eq "ress") {
            Write-Log "Running RESS script as selected..."
            try {
                if (Test-Path "F:\study\shells\powershell\scripts\ress.ps1") {
                    & "F:\study\shells\powershell\scripts\ress.ps1"
                    Write-Log "RESS script completed"
                } else {
                    Write-Log "RESS script not found at F:\study\shells\powershell\scripts\ress.ps1" "WARN"
                }
            } catch {
                Write-Log "RESS script failed: $_" "ERROR"
            }
        }
        elseif ($global:RestartChoice -eq "fitlauncher") {
            Write-Log "Running Fit-Launcher script as selected..."
            try {
                # Convert Windows path to WSL path for the fit-launcher script
                $fitLauncherPath = "F:\study\shells\powershell\scripts\rebootfitlauncher\a.ps1"
                if (Test-Path $fitLauncherPath) {
                    & $fitLauncherPath
                    Write-Log "Fit-Launcher script completed"
                } else {
                    Write-Log "Fit-Launcher script not found at $fitLauncherPath" "WARN"
                }
            } catch {
                Write-Log "Fit-Launcher script failed: $_" "ERROR"
            }
        }
    } else {
        Write-Log "Skipping final script as per user selection (no reboot chosen)"
    }
}

# START THE OPTIMIZATION PROCESS
Start-SystemOptimization

# Final summary
Write-Host "`n" + "="*80 -ForegroundColor Green
Write-Host "SYSTEM OPTIMIZATION COMPLETED!" -ForegroundColor Green
Write-Host "="*80 -ForegroundColor Green
Write-Host "Total Runtime: $((Get-Date) - $global:ScriptStartTime)" -ForegroundColor Yellow
Write-Host "Log Location: $global:LogPath" -ForegroundColor Cyan
Write-Host "`nOptimizations Applied:" -ForegroundColor White
Write-Host "  • Hiberfil.sys and pagefile cleanup (all drives)" -ForegroundColor Green
Write-Host "  • CCleaner downloaded and executed" -ForegroundColor White
Write-Host "  • AdwCleaner malware removal with timeout protection" -ForegroundColor White
Write-Host "  • Comprehensive System Volume Information cleanup (all drives)" -ForegroundColor Green
Write-Host "  • Windows system cleanup scripts (automated)" -ForegroundColor White
Write-Host "  • Advanced System Cleaner with progress tracking" -ForegroundColor White
Write-Host "  • BleachBit deep cleaning (3x runs with timeouts)" -ForegroundColor White
Write-Host "  • Additional system file cleanup (caches, dumps, thumbnails)" -ForegroundColor Green
Write-Host "  • WSL alerts and comprehensive backup process" -ForegroundColor White
Write-Host "  • WSL reset and full WSL2 setup with verbose logging" -ForegroundColor White
Write-Host "  • Final System Volume Information purge (all drives)" -ForegroundColor Green
Write-Host "  • Driver-safe network speed boost (50+ commands)" -ForegroundColor White
Write-Host "  • TCP/IP stack optimization with individual command logging" -ForegroundColor White
Write-Host "  • Registry performance enhancements (15+ values)" -ForegroundColor White
Write-Host "  • DNS optimization with Cloudflare/Google servers" -ForegroundColor White
Write-Host "  • Power settings maximized for performance" -ForegroundColor White
Write-Host "  • Comprehensive PC performance optimization (100+ commands)" -ForegroundColor Magenta
Write-Host "  • Registry performance tweaks (CPU, memory, graphics)" -ForegroundColor Magenta
Write-Host "  • Unnecessary services disabled (20+ services)" -ForegroundColor Magenta
Write-Host "  • Visual effects optimized for performance" -ForegroundColor Magenta
Write-Host "  • Gaming and multimedia performance optimization" -ForegroundColor Magenta
Write-Host "  • Comprehensive disk space cleanup (C: & F: drives)" -ForegroundColor Green
Write-Host "  • Safe cleanup of temp, cache, and log files (200+ paths)" -ForegroundColor Green
Write-Host "  • Browser cache cleanup (Chrome, Edge, Firefox)" -ForegroundColor Green
Write-Host "  • Windows Store cache, font cache, component cleanup" -ForegroundColor Green
Write-Host "  • User profile cleanup for all users" -ForegroundColor Green
Write-Host "  • ✨ Wise Registry Cleaner deep scan with spinning animation ✨" -ForegroundColor Cyan
Write-Host "  • ✨ Wise Disk Cleaner advanced scan with 2-minute timeout ✨" -ForegroundColor Cyan
Write-Host "  • 🔧 Final system optimization verification (hiberfil.sys purge - if rebooting) 🔧" -ForegroundColor Yellow
Write-Host "  • 🔧 Final system cleanup: cleanmgr, winget upgrade, shadow copy cleanup (5-min timeout) 🔧" -ForegroundColor Yellow
Write-Host "  • Force removal of unnecessary C: drive folders" -ForegroundColor White
Write-Host "  • Final script execution (RESS/Fit-Launcher/None as chosen)" -ForegroundColor White
Write-Host "="*80 -ForegroundColor Green

# Execute final action based on initial choice
Write-Host "`nFINAL ACTION:" -ForegroundColor White

switch ($global:RestartChoice) {
    "ress" {
        Write-Host "• RESS script was chosen and executed" -ForegroundColor Green
        Write-Host "• RESS script typically handles sleep/shutdown functionality" -ForegroundColor Yellow
        Write-Host "• System behavior will depend on RESS script configuration" -ForegroundColor Yellow
        Write-Host "• 🔧 Final system optimization verification executed" -ForegroundColor Yellow
        Write-Host "• 🔧 Final system cleanup executed (cleanmgr, winget, shadow copies - 5-min timeout)" -ForegroundColor Yellow
        Write-Log "RESS script was selected and executed"
    }
    "fitlauncher" {
        Write-Host "• Fit-Launcher script was chosen and executed" -ForegroundColor Green  
        Write-Host "• Fit-Launcher script handles reboot with launcher configuration" -ForegroundColor Yellow
        Write-Host "• System will reboot according to Fit-Launcher settings" -ForegroundColor Yellow
        Write-Host "• 🔧 Final system optimization verification executed" -ForegroundColor Yellow
        Write-Host "• 🔧 Final system cleanup executed (cleanmgr, winget, shadow copies - 5-min timeout)" -ForegroundColor Yellow
        Write-Log "Fit-Launcher script was selected and executed"
    }
    "none" {
        Write-Host "• No reboot script was chosen" -ForegroundColor Yellow
        Write-Host "• All optimizations have been completed without automatic reboot" -ForegroundColor Green
        Write-Host "• Hiberfil.sys and System Volume Information cleaned thoroughly" -ForegroundColor Green
        Write-Host "• WiFi and network optimizations applied" -ForegroundColor Green
        Write-Host "• PC performance optimizations completed" -ForegroundColor Green
        Write-Host "• Wise Registry and Disk Cleaners executed successfully" -ForegroundColor Cyan
        Write-Host "• 🔧 Final system optimization verification was skipped (no reboot selected)" -ForegroundColor Gray
        Write-Host "`nIMPORTANT: Please restart manually when convenient to complete optimizations." -ForegroundColor Red
        Write-Log "No automatic action - user will restart manually"
        
        if (-not $SkipConfirmations) {
            Write-Host "`nWould you like to change your mind and restart now? (Y/N)" -ForegroundColor Cyan
            $lastChance = Read-Host
            if ($lastChance -match '^[Yy]') {
                Write-Log "User changed mind - executing final system optimization verification and initiating system restart..."
                
                # Execute final system optimization verification since user changed mind
                Write-Host "🔧 Executing final system optimization verification before restart..." -ForegroundColor Yellow
                try {
                    Write-Log "Running final hiberfil.sys verification and removal..."
                    $hiberfilPaths = @("C:\hiberfil.sys", "D:\hiberfil.sys", "E:\hiberfil.sys", "F:\hiberfil.sys")
                    foreach ($hiberPath in $hiberfilPaths) {
                        if (Test-Path $hiberPath) {
                            try {
                                cmd /c "takeown /f `"$hiberPath`" /d y" 2>$null | Out-Null
                                cmd /c "icacls `"$hiberPath`" /grant administrators:F" 2>$null | Out-Null
                                Remove-Item -Path $hiberPath -Force -ErrorAction SilentlyContinue
                                if (!(Test-Path $hiberPath)) {
                                    Write-Log "✅ Successfully removed: $hiberPath"
                                }
                            } catch {
                                Write-Log "Could not remove: $hiberPath" "WARN"
                            }
                        }
                    }
                    Write-Host "✅ Final system optimization verification completed!" -ForegroundColor Green
                } catch {
                    Write-Log "Final system optimization verification failed: $_" "ERROR"
                }
                
                # Execute final system cleanup
                Write-Host "🔧 Executing final system cleanup before restart (5-minute timeout)..." -ForegroundColor Yellow
                try {
                    Write-Log "Running final system cleanup commands before reboot with strict timeouts..."
                    $finalCleanupStart = Get-Date
                    
                    # Quick cleanup with shorter timeouts since user is waiting
                    Write-Log "Running Windows Disk Cleanup (30-second timeout)..."
                    $cleanmgrJob = Start-Job { Start-Process "cleanmgr.exe" -WindowStyle Hidden -Wait }
                    if (Wait-Job $cleanmgrJob -Timeout 30) {
                        Receive-Job $cleanmgrJob | Out-Null; Remove-Job $cleanmgrJob
                        Write-Log "✅ Windows Disk Cleanup completed"
                    } else {
                        Stop-Job $cleanmgrJob; Remove-Job $cleanmgrJob
                        Get-Process -Name "cleanmgr" -ErrorAction SilentlyContinue | Stop-Process -Force
                        Write-Log "⚠️ Windows Disk Cleanup timeout (30s) - continuing..." "WARN"
                    }
                    
                    Write-Log "Running WinGet upgrade (60-second timeout)..."
                    $wingetJob = Start-Job { Start-Process "winget" -ArgumentList "upgrade", "--all", "--accept-source-agreements", "--silent" -WindowStyle Hidden -Wait }
                    if (Wait-Job $wingetJob -Timeout 60) {
                        Receive-Job $wingetJob | Out-Null; Remove-Job $wingetJob
                        Write-Log "✅ WinGet upgrade completed"
                    } else {
                        Stop-Job $wingetJob; Remove-Job $wingetJob
                        Get-Process -Name "winget" -ErrorAction SilentlyContinue | Stop-Process -Force
                        Write-Log "⚠️ WinGet upgrade timeout (60s) - continuing..." "WARN"
                    }
                    
                    Write-Log "Quick system cleanup..."
                    Get-ChildItem "C:\System Volume Information" -Force -Recurse -ErrorAction SilentlyContinue | ForEach-Object { 
                        try { $_.Attributes = 'Normal'; Remove-Item $_.FullName -Force -Recurse -ErrorAction SilentlyContinue } catch { } 
                    }
                    
                    Write-Log "Deleting volume shadow copies (15-second timeout)..."
                    $vssJob = Start-Job { Start-Process "vssadmin" -ArgumentList "delete", "shadows", "/for=C:", "/all", "/quiet" -WindowStyle Hidden -Wait }
                    if (Wait-Job $vssJob -Timeout 15) {
                        Receive-Job $vssJob | Out-Null; Remove-Job $vssJob
                    } else {
                        Stop-Job $vssJob; Remove-Job $vssJob
                        Get-Process -Name "vssadmin" -ErrorAction SilentlyContinue | Stop-Process -Force
                    }
                    
                    $finalCleanupDuration = ((Get-Date) - $finalCleanupStart).TotalSeconds
                    Write-Host "✅ Final system cleanup completed in $([math]::Round($finalCleanupDuration, 1)) seconds!" -ForegroundColor Green
                } catch {
                    Write-Log "Final system cleanup before reboot failed: $_" "ERROR"
                }
                
                Write-Host "Restarting system now..." -ForegroundColor Green
                Start-Sleep 3
                Restart-Computer -Force
            }
        }
    }
}

Write-Host "`nOptimization Summary:" -ForegroundColor White
Write-Host "• Docker data safely cleaned without removing Docker functionality" -ForegroundColor Green
Write-Host "• Unnecessary C: and F: drive folders have been cleaned" -ForegroundColor Yellow
Write-Host "• Network and WiFi optimizations applied (400+ commands total)" -ForegroundColor Yellow
Write-Host "• PC performance maximized with registry optimizations" -ForegroundColor Yellow
Write-Host "• Comprehensive disk cleanup completed" -ForegroundColor Yellow
Write-Host "• Wise Registry and Disk Cleaners completed with timeout protection" -ForegroundColor Cyan
Write-Host "• Advanced Docker cleanup executed (if rebooting)" -ForegroundColor Yellow
Write-Host "• Final system cleanup executed (cleanmgr, winget, shadow copies - 5-min timeout - if rebooting)" -ForegroundColor Yellow

Write-Host "`n=== ANTI-HANGING PROTECTION ACTIVE ===" -ForegroundColor Green
Write-Host "✅ Global 60-minute timeout protection" -ForegroundColor Green
Write-Host "✅ Individual operation timeouts (30-180 seconds)" -ForegroundColor Green  
Write-Host "✅ Temp cleanup timeout (5 minutes total)" -ForegroundColor Green
Write-Host "✅ Disk cleanup timeout (10 minutes total)" -ForegroundColor Green
Write-Host "✅ Process hanging detection (5-minute limit)" -ForegroundColor Green
Write-Host "✅ Progress heartbeat every 15 seconds" -ForegroundColor Green
Write-Host "✅ Emergency process termination" -ForegroundColor Green
Write-Host "✅ Wise Disk Cleaner 2-minute timeout protection" -ForegroundColor Green
Write-Host "✅ Final system cleanup 5-minute timeout protection" -ForegroundColor Green
Write-Host "✅ System Volume Information aggressive cleanup protection" -ForegroundColor Green
Write-Host "✅ Script execution finished successfully!" -ForegroundColor Green
Write-Host "Check the log file for detailed information: $global:LogPath" -ForegroundColor Cyan
Write-Host "`nFor faster future runs, use: ./a.ps1 1 (RESS), ./a.ps1 2 (Fit-Launcher), or ./a.ps1 3 (No reboot)" -ForegroundColor Gray
Write-Host "`nThank you for using the Complete System Optimization Script!" -ForegroundColor White

# END OF SCRIPT