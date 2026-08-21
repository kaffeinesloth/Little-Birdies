param(
    [switch]$LocalAI,
    [switch]$NoBuild
)

$ErrorActionPreference = 'Stop'
$ProjectRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
Set-Location -LiteralPath $ProjectRoot

& (Join-Path $PSScriptRoot 'demo-doctor.ps1') -LocalAI:$LocalAI

if ($LocalAI) {
    Write-Host 'Starting Smart Helpdesk with local Ollama AI...' -ForegroundColor Cyan
    $DockerArgs = @('compose', '--profile', 'local-ai', 'up', '--detach', '--wait')
} else {
    Write-Host 'Starting the reliable fallback demo...' -ForegroundColor Cyan
    $DockerArgs = @('compose', 'up', '--detach', '--wait')
}

if (-not $NoBuild) {
    $DockerArgs += '--build'
}

& docker @DockerArgs
if ($LASTEXITCODE -ne 0) {
    throw 'Docker Compose could not start the demo. Run .\scripts\demo-doctor.ps1 and inspect docker compose logs.'
}

if ($LocalAI) {
    Write-Host 'Waiting for Ollama model readiness. First run can take several minutes while models download...' -ForegroundColor Cyan
    $Deadline = (Get-Date).AddMinutes(20)
    $Ready = $false
    while ((Get-Date) -lt $Deadline) {
        try {
            $Health = Invoke-RestMethod -Uri 'http://localhost:8001/health' -TimeoutSec 5
            if ($Health.provider -eq 'ollama' -and $Health.runtime_ready -eq $true) {
                $Ready = $true
                break
            }
            Write-Host ("AI health: provider={0}, runtime_ready={1}" -f $Health.provider, $Health.runtime_ready)
        } catch {
            Write-Host 'AI health endpoint is not ready yet.'
        }
        Start-Sleep -Seconds 15
    }
    if (-not $Ready) {
        throw 'Local AI did not become ready within 20 minutes. Run "docker compose --profile local-ai logs ollama-init ollama ai-service" to inspect model download/startup.'
    }
}

Write-Host ''
Write-Host 'Smart Helpdesk is ready.' -ForegroundColor Green
Write-Host 'Customer store:  http://localhost:3000'
Write-Host 'Staff workspace: http://localhost:8080'
Write-Host 'Backend docs:    http://localhost:8000/api/docs'
Write-Host 'AI health:       http://localhost:8001/health'
Write-Host ''
Write-Host 'Stop later with: docker compose down'
