#Requires -Version 7

param(
    [Parameter(Position = 0)]
    [string]$TargetDir
)

if (-not $TargetDir -and $args.Count -gt 0) {
    $TargetDir = $args -join ' '
}

. "$PSScriptRoot\MklinkCore.ps1"

$errorLogPath = Join-Path $PSScriptRoot 'error_log.txt'

try {
    $sourcePath = Get-MklinkPendingSource
    if (-not $sourcePath) {
        Write-Host 'No source folder selected!' -ForegroundColor Red
        Write-Host "Right-click a folder and select 'mklink > Set as source' first." -ForegroundColor Yellow
        Start-Sleep 3
        exit
    }

    Write-Host ''
    Write-Host '=== mklink Move & Junction ===' -ForegroundColor Cyan
    Write-Host ''
    Write-Host "Source: $sourcePath" -ForegroundColor White
    Write-Host "Destination folder: $TargetDir" -ForegroundColor White
    Write-Host ''

    $result = New-MklinkJunctionMove -SourcePath $sourcePath -TargetDirectory $TargetDir

    Write-Host '[OK] Folder moved and junction created.' -ForegroundColor Green
    Write-Host "Junction: $($result.LinkPath)" -ForegroundColor White
    Write-Host "Target:   $($result.TargetPath)" -ForegroundColor White
    Start-Sleep 2
}
catch {
    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $errorMessage = "[$timestamp] TARGET ERROR: $($_.Exception.Message)`nStack Trace: $($_.ScriptStackTrace)`n---`n"
    Add-Content -LiteralPath $errorLogPath -Value $errorMessage

    Write-Host "`n[ERROR] $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Error logged to: $errorLogPath" -ForegroundColor Yellow
    Write-Host 'Press any key to exit...' -ForegroundColor Yellow
    [Console]::ReadKey($true) | Out-Null
}
