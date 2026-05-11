#Requires -Version 7

param(
    [Parameter(Position = 0)]
    [string]$FolderPath
)

if (-not $FolderPath -and $args.Count -gt 0) {
    $FolderPath = $args -join ' '
}

. "$PSScriptRoot\MklinkCore.ps1"

try {
    [void](Set-MklinkPendingSource -SourcePath $FolderPath)
}
catch {
    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $errorLogPath = Join-Path $PSScriptRoot 'error_log.txt'
    Add-Content -LiteralPath $errorLogPath -Value "[$timestamp] SOURCE ERROR: $($_.Exception.Message)"
}
