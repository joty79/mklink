#Requires -Version 7

param(
    [Parameter(Position = 0)]
    [string]$LinkPath
)

if (-not $LinkPath -and $args.Count -gt 0) {
    $LinkPath = $args -join ' '
}

. "$PSScriptRoot\MklinkCore.ps1"

$errorLogPath = Join-Path $PSScriptRoot 'error_log.txt'

try {
    $info = Assert-MklinkJunction -LinkPath $LinkPath

    Write-Host ''
    Write-Host '=== mklink Revert Junction ===' -ForegroundColor Cyan
    Write-Host ''
    Write-Host "Junction: $($info.Path)" -ForegroundColor White
    Write-Host "Target:   $($info.Target)" -ForegroundColor White
    Write-Host ''
    Write-Host 'This removes the junction and moves the target folder back to the original path.' -ForegroundColor Yellow
    $answer = Read-Host 'Type YES to continue'
    if ($answer -ne 'YES') {
        Write-Host 'Cancelled.' -ForegroundColor Yellow
        Start-Sleep 2
        exit
    }

    $result = Revert-MklinkJunction -LinkPath $LinkPath

    Write-Host ''
    Write-Host "[OK] Reverted: $($result.RestoredPath)" -ForegroundColor Green
    Start-Sleep 2
}
catch {
    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $errorMessage = "[$timestamp] REVERT ERROR: $($_.Exception.Message)`nStack Trace: $($_.ScriptStackTrace)`n---`n"
    Add-Content -LiteralPath $errorLogPath -Value $errorMessage

    Write-Host "`n[ERROR] $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Error logged to: $errorLogPath" -ForegroundColor Yellow
    Write-Host 'Press any key to exit...' -ForegroundColor Yellow
    [Console]::ReadKey($true) | Out-Null
}
