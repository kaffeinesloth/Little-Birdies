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

Write-Host ''
Write-Host 'Smart Helpdesk is ready.' -ForegroundColor Green
Write-Host 'Customer store:  http://localhost:3000'
Write-Host 'Staff workspace: http://localhost:8080'
Write-Host 'Backend docs:    http://localhost:8000/api/docs'
Write-Host 'AI health:       http://localhost:8001/health'
Write-Host ''
Write-Host 'Stop later with: docker compose down'
