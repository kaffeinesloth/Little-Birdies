[CmdletBinding()]
param(
    [switch]$SkipInstall,
    [switch]$OpenBrowser
)

$ErrorActionPreference = "Stop"

$projectRoot = $PSScriptRoot
$runtimeRoot = Join-Path $projectRoot ".smart-helpdesk"
$logsRoot = Join-Path $runtimeRoot "logs"
$statePath = Join-Path $runtimeRoot "processes.json"
$startedProcesses = [System.Collections.Generic.List[object]]::new()

# Pick up tools installed after the parent terminal or editor was opened.
$machinePath = [Environment]::GetEnvironmentVariable("Path", "Machine")
$userPath = [Environment]::GetEnvironmentVariable("Path", "User")
$env:Path = @($machinePath, $userPath) -join ";"

function Write-Step {
    param([string]$Message)
    Write-Host "`n==> $Message" -ForegroundColor Cyan
}

function Assert-PortAvailable {
    param([int]$Port)

    $listener = Get-NetTCPConnection -State Listen -LocalPort $Port -ErrorAction SilentlyContinue |
        Select-Object -First 1
    if ($listener) {
        throw "Port $Port is already in use by process $($listener.OwningProcess). Stop it or change the project port."
    }
}

function Invoke-Checked {
    param(
        [string]$Executable,
        [string[]]$Arguments,
        [string]$WorkingDirectory
    )

    Push-Location $WorkingDirectory
    $savedErrorPreference = $ErrorActionPreference
    try {
        # Native tools often write progress or warnings to stderr. Judge success
        # by their exit code instead of turning those messages into exceptions.
        $ErrorActionPreference = "Continue"
        & $Executable @Arguments 2>&1 | Out-Host
        $nativeExitCode = $LASTEXITCODE
        $ErrorActionPreference = $savedErrorPreference
        if ($nativeExitCode -ne 0) {
            throw "Command failed with exit code ${nativeExitCode}: $Executable $($Arguments -join ' ')"
        }
    }
    finally {
        $ErrorActionPreference = $savedErrorPreference
        Pop-Location
    }
}

function Ensure-PythonService {
    param(
        [string]$ServiceDirectory,
        [string]$ImportCheck
    )

    $venvPython = Join-Path $ServiceDirectory ".venv\Scripts\python.exe"
    if (-not (Test-Path -LiteralPath $venvPython)) {
        if ($SkipInstall) {
            throw "Missing Python environment in $ServiceDirectory. Run start.cmd without -SkipInstall first."
        }
        Write-Step "Creating Python environment for $ServiceDirectory"
        Invoke-Checked -Executable $script:systemPython -Arguments @("-m", "venv", ".venv") -WorkingDirectory $ServiceDirectory
    }

    $savedErrorPreference = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    & $venvPython -c $ImportCheck 2>$null
    $importExitCode = $LASTEXITCODE
    $ErrorActionPreference = $savedErrorPreference
    if ($importExitCode -ne 0) {
        if ($SkipInstall) {
            throw "Python dependencies are missing in $ServiceDirectory. Run start.cmd without -SkipInstall first."
        }
        Write-Step "Installing Python dependencies for $ServiceDirectory"
        Invoke-Checked -Executable $venvPython -Arguments @("-m", "pip", "install", "-r", "requirements.txt") -WorkingDirectory $ServiceDirectory
    }

    return $venvPython
}

function Start-TrackedProcess {
    param(
        [string]$Name,
        [string]$Executable,
        [string[]]$Arguments,
        [string]$WorkingDirectory,
        [int]$Port
    )

    $stdoutPath = Join-Path $logsRoot "$Name.out.log"
    $stderrPath = Join-Path $logsRoot "$Name.err.log"
    $process = Start-Process `
        -FilePath $Executable `
        -ArgumentList $Arguments `
        -WorkingDirectory $WorkingDirectory `
        -WindowStyle Hidden `
        -RedirectStandardOutput $stdoutPath `
        -RedirectStandardError $stderrPath `
        -PassThru

    $record = [pscustomobject]@{
        name = $Name
        port = $Port
        launchPid = $process.Id
        pid = $process.Id
        launchStartedAtUtc = $process.StartTime.ToUniversalTime().ToString("o")
        startedAtUtc = $process.StartTime.ToUniversalTime().ToString("o")
        stdout = $stdoutPath
        stderr = $stderrPath
    }
    $startedProcesses.Add($record)
    return $record
}

function Wait-ForService {
    param(
        [object]$Record,
        [string]$HealthUrl,
        [int]$TimeoutSeconds = 60
    )

    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    while ((Get-Date) -lt $deadline) {
        $launcher = Get-Process -Id $Record.launchPid -ErrorAction SilentlyContinue
        if (-not $launcher) {
            $errorText = if (Test-Path -LiteralPath $Record.stderr) {
                (Get-Content -LiteralPath $Record.stderr -Tail 20) -join "`n"
            } else {
                "No error log was produced."
            }
            throw "$($Record.name) stopped during startup.`n$errorText"
        }

        try {
            $null = Invoke-WebRequest -Uri $HealthUrl -UseBasicParsing -TimeoutSec 2
            $listener = Get-NetTCPConnection -State Listen -LocalPort $Record.port -ErrorAction SilentlyContinue |
                Select-Object -First 1
            if ($listener) {
                $Record.pid = [int]$listener.OwningProcess
                $listenerProcess = Get-Process -Id $Record.pid -ErrorAction SilentlyContinue
                if ($listenerProcess) {
                    $Record.startedAtUtc = $listenerProcess.StartTime.ToUniversalTime().ToString("o")
                }
            }
            return
        }
        catch {
            Start-Sleep -Milliseconds 500
        }
    }

    throw "$($Record.name) did not become ready within $TimeoutSeconds seconds. See $($Record.stderr)."
}

function Stop-StartedProcesses {
    foreach ($record in $startedProcesses) {
        @($record.pid, $record.launchPid) |
            Select-Object -Unique |
            ForEach-Object {
                if ($_ -and (Get-Process -Id $_ -ErrorAction SilentlyContinue)) {
                    Stop-Process -Id $_ -ErrorAction SilentlyContinue
                }
            }
    }
}

try {
    if (Test-Path -LiteralPath $statePath) {
        $oldState = Get-Content -LiteralPath $statePath -Raw | ConvertFrom-Json
        $live = @($oldState.processes | Where-Object { Get-Process -Id $_.pid -ErrorAction SilentlyContinue })
        if ($live.Count -gt 0) {
            throw "Smart Helpdesk appears to be running already. Use .\stop.cmd before starting it again."
        }
        Remove-Item -LiteralPath $statePath -Force
    }

    New-Item -ItemType Directory -Path $logsRoot -Force | Out-Null
    3000, 8000, 8001 | ForEach-Object { Assert-PortAvailable -Port $_ }

    $pythonCommand = Get-Command python.exe -ErrorAction SilentlyContinue
    if (-not $pythonCommand) {
        throw "Python was not found. Install Python 3.12 or newer and add it to PATH."
    }
    $script:systemPython = $pythonCommand.Source

    $aiDirectory = Join-Path $projectRoot "services\ai"
    $apiDirectory = Join-Path $projectRoot "services\api"
    $webDirectory = Join-Path $projectRoot "apps\web-admin"

    $aiPython = Ensure-PythonService -ServiceDirectory $aiDirectory `
        -ImportCheck "import fastapi, uvicorn, pydantic_settings, httpx, chromadb, pypdf, docx"
    $apiPython = Ensure-PythonService -ServiceDirectory $apiDirectory `
        -ImportCheck "import fastapi, uvicorn, pydantic_settings, httpx, jwt"

    $nodeCommand = Get-Command node.exe -ErrorAction SilentlyContinue
    $pnpmCommand = Get-Command pnpm.cmd -ErrorAction SilentlyContinue
    if (-not $nodeCommand -or -not $pnpmCommand) {
        throw "Node.js and pnpm are required. Install Node.js, then run: npm install -g pnpm"
    }

    $nextCli = Join-Path $webDirectory "node_modules\next\dist\bin\next"
    if (-not (Test-Path -LiteralPath $nextCli)) {
        if ($SkipInstall) {
            throw "Web dependencies are missing. Run start.cmd without -SkipInstall first."
        }
        Write-Step "Installing web dependencies"
        Invoke-Checked -Executable $pnpmCommand.Source -Arguments @("install", "--frozen-lockfile") -WorkingDirectory $webDirectory
    }

    $env:APP_ENV = "development"
    $env:RAG_CONFIDENCE_THRESHOLD = "0.0"
    $env:CHROMA_DB_PATH = (Join-Path $aiDirectory "chroma")
    $env:LOCAL_MOCK_AUTH_ENABLED = "true"
    $env:AI_SERVICE_URL = "http://127.0.0.1:8001"
    $env:NEXT_PUBLIC_API_BASE_URL = "http://127.0.0.1:8000"

    Write-Step "Starting AI service on http://127.0.0.1:8001"
    $ai = Start-TrackedProcess -Name "ai" -Executable $aiPython `
        -Arguments @("-m", "uvicorn", "app.main:app", "--host", "127.0.0.1", "--port", "8001") `
        -WorkingDirectory $aiDirectory -Port 8001
    Wait-ForService -Record $ai -HealthUrl "http://127.0.0.1:8001/health"

    Write-Step "Loading the sample knowledge base"
    $samplePath = Join-Path $projectRoot "docs\demo-data\sample-support-policy.txt"
    $documentBody = @{
        document_id = "demo-support-policy"
        file_url = $samplePath
        file_type = "txt"
        file_name = "sample-support-policy.txt"
        file_size_bytes = (Get-Item -LiteralPath $samplePath).Length
    } | ConvertTo-Json
    $null = Invoke-RestMethod -Uri "http://127.0.0.1:8001/documents/process" `
        -Method Post -ContentType "application/json" -Body $documentBody

    Write-Step "Starting backend API on http://127.0.0.1:8000"
    $api = Start-TrackedProcess -Name "api" -Executable $apiPython `
        -Arguments @("-m", "uvicorn", "app.main:app", "--host", "127.0.0.1", "--port", "8000") `
        -WorkingDirectory $apiDirectory -Port 8000
    Wait-ForService -Record $api -HealthUrl "http://127.0.0.1:8000/health"

    Write-Step "Starting web dashboard on http://127.0.0.1:3000"
    $web = Start-TrackedProcess -Name "web" -Executable $nodeCommand.Source `
        -Arguments @($nextCli, "dev", "--hostname", "127.0.0.1", "--port", "3000") `
        -WorkingDirectory $webDirectory -Port 3000
    Wait-ForService -Record $web -HealthUrl "http://127.0.0.1:3000/login" -TimeoutSeconds 90

    $state = [pscustomobject]@{
        projectRoot = $projectRoot
        createdAtUtc = (Get-Date).ToUniversalTime().ToString("o")
        processes = @($startedProcesses)
    }
    $state | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $statePath -Encoding UTF8

    Write-Host "`nSmart Helpdesk is running." -ForegroundColor Green
    Write-Host "Login:  http://127.0.0.1:3000/login"
    Write-Host "Widget: http://127.0.0.1:3000/widget-demo"
    Write-Host "Account: owner@example.com / password"
    Write-Host "Logs:   $logsRoot"
    Write-Host "Stop:   .\stop.cmd"

    if ($OpenBrowser) {
        Start-Process "http://127.0.0.1:3000/login"
    }
}
catch {
    $failure = $_
    Stop-StartedProcesses
    if (Test-Path -LiteralPath $statePath) {
        Remove-Item -LiteralPath $statePath -Force
    }
    Write-Error -ErrorRecord $failure
    exit 1
}
