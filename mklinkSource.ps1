# mklink Source - Stores the folder path for junction creation
# Silent execution - just stores in registry

param([string]$folderPath)

# If no argument, try to reconstruct from $args
if (-not $folderPath -and $args.Count -gt 0) {
    $folderPath = $args -join " "
}

$regPath = "HKCU:\RCWM\mklink"

# Ensure registry key exists
if (-not (Test-Path $regPath)) {
    New-Item -Path $regPath -Force | Out-Null
}
else {
    # Clear previous entry
    Remove-ItemProperty -Path $regPath -Name * -ErrorAction SilentlyContinue
}

# Store the source path
New-ItemProperty -Path $regPath -Name "SourcePath" -Value $folderPath -Force | Out-Null
