param(
    [switch]$LocalAI
)

$ErrorActionPreference = 'Stop'
$ProjectRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
Set-Location -LiteralPath $ProjectRoot

Write-Host 'Smart Helpdesk demo check' -ForegroundColor Cyan

if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
    throw 'Docker was not found. Install and start Docker Desktop first.'
}

docker compose version
docker info --format 'Docker engine: {{.ServerVersion}}'
docker compose config --services

$SystemDrive = Get-PSDrive -Name ([System.IO.Path]::GetPathRoot($ProjectRoot).TrimEnd(':\'))
if ($SystemDrive.Free -lt 8GB) {
    Write-Warning 'Less than 8 GB is free on the project drive. Docker builds may fail.'
} else {
    Write-Host ("Free disk space: {0:N1} GB" -f ($SystemDrive.Free / 1GB)) -ForegroundColor Green
}

$Ports = 3000, 8000, 8001, 8080
if ($LocalAI) { $Ports += 11434 }

foreach ($Port in $Ports) {
    $InUse = Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue
    if ($InUse) {
        Write-Warning "Port $Port is already in use. Stop that application before the demo."
    } else {
        Write-Host "Port $Port is available." -ForegroundColor Green
    }
}

if ($LocalAI) {
    if (Get-Command nvidia-smi -ErrorAction SilentlyContinue) {
        nvidia-smi --query-gpu=name,memory.total --format=csv,noheader
    } else {
        Write-Warning 'No NVIDIA runtime was detected. Ollama will run on CPU, which is slower but works for the demo.'
    }
}

Write-Host 'Preflight check complete.' -ForegroundColor Green
