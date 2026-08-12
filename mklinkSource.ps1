#Requires -Version 7

param(
    [Parameter(Position = 0)]
    [string]$FolderPath,

    [Parameter(Position = 1)]
    [ValidateSet('MoveSource', 'ExistingTarget')]
    [string]$Mode = 'MoveSource'
)

if (-not $FolderPath -and $args.Count -gt 0) {
    $FolderPath = $args -join ' '
}

. "$PSScriptRoot\MklinkCore.ps1"

try {
    if ($Mode -eq 'ExistingTarget') {
        [void](Set-MklinkPendingExistingTarget -TargetPath $FolderPath)
    }
    else {
        [void](Set-MklinkPendingSource -SourcePath $FolderPath)
    }
}
catch {
    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $errorLogPath = Get-MklinkDataPath -SubFolder 'logs' -FileName 'error_log.txt'
    Add-Content -LiteralPath $errorLogPath -Value "[$timestamp] SOURCE ERROR: $($_.Exception.Message)"
}
