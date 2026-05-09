# mklink Target - Moves folder here and creates junction at original location
# Runs with admin rights in Windows Terminal

param([string]$targetDir)

# If no argument, try to reconstruct from $args
if (-not $targetDir -and $args.Count -gt 0) {
    $targetDir = $args -join " "
}

$regPath = "HKCU:\RCWM\mklink"

# Error log
$errorLogPath = "$PSScriptRoot\error_log.txt"

try {
    # Check if source path exists in registry
    if (-not (Test-Path $regPath)) {
        Write-Host "No source folder selected!" -ForegroundColor Red
        Write-Host "Right-click on a folder and select 'mklink Source' first." -ForegroundColor Yellow
        Start-Sleep 3
        exit
    }

    $sourcePath = (Get-ItemProperty -Path $regPath -Name "SourcePath" -ErrorAction SilentlyContinue).SourcePath

    if (-not $sourcePath) {
        Write-Host "No source folder selected!" -ForegroundColor Red
        Write-Host "Right-click on a folder and select 'mklink Source' first." -ForegroundColor Yellow
        Start-Sleep 3
        exit
    }

    # Check if source folder exists
    if (-not (Test-Path $sourcePath)) {
        Write-Host "Source folder does not exist: $sourcePath" -ForegroundColor Red
        Start-Sleep 3
        exit
    }

    # Get folder name
    $folderName = Split-Path $sourcePath -Leaf
    $newLocation = Join-Path $targetDir $folderName

    # Check if folder already exists at target
    if (Test-Path $newLocation) {
        Write-Host "Folder already exists at target: $newLocation" -ForegroundColor Red
        Write-Host "Cannot continue!" -ForegroundColor Yellow
        Start-Sleep 3
        exit
    }

    Write-Host ""
    Write-Host "=== mklink Move & Junction ===" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Source: $sourcePath" -ForegroundColor White
    Write-Host "Target: $newLocation" -ForegroundColor White
    Write-Host ""

    # Step 1: Move the folder
    Write-Host "[1/2] Moving folder..." -ForegroundColor Yellow
    Move-Item -Path $sourcePath -Destination $newLocation -Force
    Write-Host "      Moved to: $newLocation" -ForegroundColor Green

    # Step 2: Create junction at original location
    Write-Host "[2/2] Creating junction..." -ForegroundColor Yellow
    cmd /c mklink /J "$sourcePath" "$newLocation"
    Write-Host "      Junction created: $sourcePath -> $newLocation" -ForegroundColor Green

    # Clear registry
    Remove-ItemProperty -Path $regPath -Name * -ErrorAction SilentlyContinue

    Write-Host ""
    Write-Host "Done!" -ForegroundColor Blue
    Start-Sleep 2

}
catch {
    # Log error
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $errorMessage = "[$timestamp] ERROR: $($_.Exception.Message)`nStack Trace: $($_.ScriptStackTrace)`n---`n"
    Add-Content -Path $errorLogPath -Value $errorMessage
    
    Write-Host "`n[ERROR] $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Error logged to: $errorLogPath" -ForegroundColor Yellow
    Write-Host "Press any key to exit..." -ForegroundColor Yellow
    [Console]::ReadKey($true) | Out-Null
}
