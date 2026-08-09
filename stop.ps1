[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"

$runtimeRoot = Join-Path $PSScriptRoot ".smart-helpdesk"
$statePath = Join-Path $runtimeRoot "processes.json"

if (-not (Test-Path -LiteralPath $statePath)) {
    Write-Host "Smart Helpdesk is not running, or it was not started with start.cmd." -ForegroundColor Yellow
    exit 0
}

try {
    $state = Get-Content -LiteralPath $statePath -Raw | ConvertFrom-Json
}
catch {
    throw "Cannot read $statePath. No processes were stopped."
}

$stopped = 0
$skipped = 0

foreach ($record in @($state.processes)) {
    foreach ($processId in @($record.pid, $record.launchPid) | Select-Object -Unique) {
        if (-not $processId) {
            continue
        }

        $process = Get-Process -Id $processId -ErrorAction SilentlyContinue
        if (-not $process) {
            continue
        }

        # Guard against stopping an unrelated process if Windows has reused a PID.
        $recordedTimestamp = if ($processId -eq $record.launchPid) {
            $record.launchStartedAtUtc
        }
        else {
            $record.startedAtUtc
        }
        try {
            $recordedStart = [DateTime]::Parse($recordedTimestamp).ToUniversalTime()
            $actualStartValue = $process.StartTime
            if (-not $actualStartValue) {
                # The process finished naturally after Get-Process returned it.
                continue
            }
            $actualStart = $actualStartValue.ToUniversalTime()
        }
        catch {
            if (-not (Get-Process -Id $processId -ErrorAction SilentlyContinue)) {
                continue
            }
            throw
        }
        if ([Math]::Abs(($actualStart - $recordedStart).TotalSeconds) -gt 10) {
            Write-Warning "Skipped PID $processId because its start time does not match the recorded $($record.name) process."
            $skipped++
            continue
        }

        try {
            Stop-Process -Id $processId -ErrorAction Stop
        }
        catch {
            if (-not (Get-Process -Id $processId -ErrorAction SilentlyContinue)) {
                continue
            }
            throw
        }
        Write-Host "Stopped $($record.name) (PID $processId)."
        $stopped++
    }
}

if ($skipped -eq 0) {
    Remove-Item -LiteralPath $statePath -Force
}
else {
    Write-Warning "The process record was kept because one or more PIDs could not be safely matched."
}

Write-Host "Smart Helpdesk stopped. $stopped process(es) terminated." -ForegroundColor Green
