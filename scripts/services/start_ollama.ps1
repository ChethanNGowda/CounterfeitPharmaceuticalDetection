# PharmaAssist Ollama Server Launcher
param(
    [string]$BaseUrl = "http://127.0.0.1:11434"
)

Write-Host "Checking Ollama status on $BaseUrl..."

try {
    $response = Invoke-RestMethod -Uri "$BaseUrl/api/tags" -TimeoutSec 3 -ErrorAction Stop
    Write-Host "Ollama is already running and responsive." -ForegroundColor Green
    if ($response.models) {
        Write-Host "Available models: $($response.models.name -join ', ')" -ForegroundColor Cyan
    }
    exit 0
} catch {
    Write-Host "Ollama not responding on $BaseUrl. Starting service..." -ForegroundColor Yellow
}

$ollamaCmd = Get-Command "ollama" -ErrorAction SilentlyContinue
if (-not $ollamaCmd) {
    $localPath = "$env:LOCALAPPDATA\Programs\Ollama\ollama.exe"
    if (Test-Path $localPath) {
        $ollamaExe = $localPath
    } else {
        Write-Error "ollama executable not found. Please install Ollama or ensure it is in PATH."
        exit 1
    }
} else {
    $ollamaExe = $ollamaCmd.Source
}

Write-Host "Starting: $ollamaExe serve"
Start-Process -FilePath $ollamaExe -ArgumentList "serve"

$ready = $false
for ($i = 0; $i -lt 15; $i++) {
    Start-Sleep -Seconds 1
    try {
        $response = Invoke-RestMethod -Uri "$BaseUrl/api/tags" -TimeoutSec 2 -ErrorAction Stop
        $ready = $true
        Write-Host "Ollama is ready!" -ForegroundColor Green
        if ($response.models) {
            Write-Host "Available models: $($response.models.name -join ', ')" -ForegroundColor Cyan
        }
        break
    } catch {
        Write-Host "." -NoNewline
    }
}
Write-Host ""

if (-not $ready) {
    Write-Warning "Ollama process launched, but $BaseUrl is not yet responding. Check server logs."
    exit 1
}

exit 0
