# system-check.ps1
# Basic system diagnostics report

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function To-GB([int64]$bytes) {
    return [math]::Round($bytes / 1GB, 2)
}

Write-Host "Running system diagnostics..." -ForegroundColor Cyan

# Timestamp & basic host info
$timestamp = Get-Date
$computerName = $env:COMPUTERNAME
$osInfo = Get-ComputerInfo | Select-Object -First 1 OSName, OSVersion, OSBuildNumber, OsHardwareAbstractionLayer

# Uptime
$os = Get-CimInstance -ClassName Win32_OperatingSystem
$uptime = (Get-Date) - $os.LastBootUpTime

# CPU & Memory
$cpu = (Get-CimInstance -ClassName Win32_Processor | Select-Object -First 1 -ExpandProperty Name)
$totalMemoryGB = To-GB((Get-CimInstance -ClassName Win32_ComputerSystem).TotalPhysicalMemory)
$availableBytes = (Get-Counter '\Memory\AvailableBytes').CounterSamples[0].CookedValue
$availableMemoryGB = To-GB([int64]$availableBytes)

# Disk usage (file system drives)
$drives = Get-PSDrive -PSProvider FileSystem | Sort-Object Name | ForEach-Object {
    [PSCustomObject]@{
        Name = $_.Name
        Root = $_.Root
        FreeGB = To-GB($_.Free)
        UsedGB = To-GB( ([math]::Max(0, ($_.Used -as [double]) )) )  # best-effort
        UsedPct = if ($_.Free -and $_.Used) { [math]::Round(($_.Used / ($_.Used + $_.Free)) * 100, 1) } else { $null }
    }
}

# Top processes by CPU
$topProcesses = Get-Process | Where-Object { $_.CPU -ne $null } | Sort-Object CPU -Descending | Select-Object -First 5 Id, ProcessName, @{Name='CPU(s)';Expression={[math]::Round($_.CPU,2)}}, @{Name='WorkingSetMB';Expression={[math]::Round($_.WorkingSet/1MB,2)}}

# Network info
$netInfo = @()
if (Get-Command Get-NetIPConfiguration -ErrorAction SilentlyContinue) {
    $netInfo = Get-NetIPConfiguration | ForEach-Object {
        [PSCustomObject]@{
            Interface = $_.InterfaceAlias
            IPv4 = ($_.IPv4Address | ForEach-Object { $_.IPAddress }) -join ', '
            IPv6 = ($_.IPv6Address | ForEach-Object { $_.IPAddress }) -join ', '
            DNSServers = ($_.DNSServer | ForEach-Object { $_.ServerAddresses }) -join ', '
        }
    }
} else {
    $netInfo = Get-NetIPAddress -ErrorAction SilentlyContinue | Select-Object InterfaceAlias, IPAddress, AddressFamily
}

# Build report object
$report = [PSCustomObject]@{
    Timestamp = $timestamp
    Computer = $computerName
    OS = $osInfo
    Uptime = @{ Days = $uptime.Days; Hours = $uptime.Hours; Minutes = $uptime.Minutes }
    CPU = $cpu
    MemoryGB = @{ Total = $totalMemoryGB; Available = $availableMemoryGB }
    Drives = $drives
    TopProcesses = $topProcesses
    Network = $netInfo
}

# Pretty output
Write-Host "`n=== Summary ===" -ForegroundColor Yellow
Write-Host "Computer: $($report.Computer)"
Write-Host "Timestamp: $($report.Timestamp)"
Write-Host "OS: $($report.OS.OSName) $($report.OS.OSVersion) (Build $($report.OS.OSBuildNumber))"
Write-Host "Uptime: $($report.Uptime.Days) days, $($report.Uptime.Hours) hours, $($report.Uptime.Minutes) minutes"
Write-Host "CPU: $($report.CPU)"
Write-Host "Memory: $($report.MemoryGB.Available) GB available of $($report.MemoryGB.Total) GB"

Write-Host "`n=== Drives ===" -ForegroundColor Yellow
$report.Drives | Format-Table -AutoSize

Write-Host "`n=== Top Processes (by CPU) ===" -ForegroundColor Yellow
$report.TopProcesses | Format-Table -AutoSize

Write-Host "`n=== Network ===" -ForegroundColor Yellow
$report.Network | Format-Table -AutoSize

# Optional: save JSON report next to script
try {
    $outFile = Join-Path -Path (Split-Path -Parent $PSCommandPath) -ChildPath ("system-check-report-{0:yyyyMMddHHmmss}.json" -f (Get-Date))
    $report | ConvertTo-Json -Depth 5 | Out-File -FilePath $outFile -Encoding UTF8
    Write-Host "`nReport saved to: $outFile" -ForegroundColor Green
} catch {
    Write-Host "`nCould not save report: $_" -ForegroundColor Red
}

Write-Host "`nDiagnostics complete." -ForegroundColor Green