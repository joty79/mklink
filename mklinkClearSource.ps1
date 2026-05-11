#Requires -Version 7

. "$PSScriptRoot\MklinkCore.ps1"

try {
    Clear-MklinkPendingSource
}
catch {
    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $errorLogPath = Join-Path $PSScriptRoot 'error_log.txt'
    Add-Content -LiteralPath $errorLogPath -Value "[$timestamp] CLEAR ERROR: $($_.Exception.Message)"
}
