# ==============================================================================
# PharmaAssist — Ollama Background Service Stop Script (PowerShell 5.1+)
# ==============================================================================
# Usage:
#   powershell -ExecutionPolicy Bypass -File scripts\stop_ollama.ps1
# ==============================================================================

[CmdletBinding()]
param ()

Write-Host "`n[PharmaAssist] Stopping Ollama service processes..." -ForegroundColor Cyan

$procs = Get-Process -Name "*ollama*" -ErrorAction SilentlyContinue

if (-not $procs) {
    Write-Host "[PharmaAssist] No Ollama processes are currently running." -ForegroundColor Gray
    exit 0
}

foreach ($p in $procs) {
    try {
        Write-Host "[PharmaAssist] Terminating process $($p.Name) (PID: $($p.Id))..." -ForegroundColor Yellow
        $p.Kill()
    } catch {
        Write-Host "[WARN] Could not terminate PID $($p.Id): $_" -ForegroundColor DarkYellow
    }
}

Start-Sleep -Seconds 1
$remaining = Get-Process -Name "*ollama*" -ErrorAction SilentlyContinue
if (-not $remaining) {
    Write-Host "[PharmaAssist] Ollama service stopped successfully." -ForegroundColor Green
} else {
    Write-Host "[WARN] Some Ollama processes could not be stopped." -ForegroundColor Red
}
exit 0
