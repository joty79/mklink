#Requires -Version 7

param(
    [Parameter(Position = 0)]
    [string]$TargetDir
)

if (-not $TargetDir -and $args.Count -gt 0) {
    $TargetDir = $args -join ' '
}

. "$PSScriptRoot\MklinkCore.ps1"

$errorLogPath = Get-MklinkDataPath -SubFolder 'logs' -FileName 'error_log.txt'

try {
    $pending = Get-MklinkPendingSelection
    if (-not $pending) {
        Write-Host 'No folder selection is pending!' -ForegroundColor Red
        Write-Host "Right-click a folder and choose 'Set as source (move)' or 'Set as existing target' first." -ForegroundColor Yellow
        Start-Sleep 3
        exit
    }

    Write-Host ''
    if ($pending.Mode -eq 'ExistingTarget') {
        Write-Host '=== mklink Existing Target ===' -ForegroundColor Cyan
        Write-Host ''
        Write-Host "Existing target: $($pending.Path)" -ForegroundColor White
        Write-Host "Junction parent: $TargetDir" -ForegroundColor White
        Write-Host ''

        $result = New-MklinkJunctionForExistingTarget -TargetPath $pending.Path -LinkParentDirectory $TargetDir
        Write-Host '[OK] Existing target kept in place and junction created.' -ForegroundColor Green
    }
    else {
        Write-Host '=== mklink Move & Junction ===' -ForegroundColor Cyan
        Write-Host ''
        Write-Host "Source: $($pending.Path)" -ForegroundColor White
        Write-Host "Destination folder: $TargetDir" -ForegroundColor White
        Write-Host ''

        $result = New-MklinkJunctionMove -SourcePath $pending.Path -TargetDirectory $TargetDir
        Write-Host '[OK] Folder moved and junction created.' -ForegroundColor Green
    }

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
