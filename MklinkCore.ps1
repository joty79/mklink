#Requires -Version 7

$script:MklinkRegistryPath = 'HKCU:\RCWM\mklink'

function Write-MklinkLog {
    param(
        [Parameter(Mandatory)]
        [string]$Message
    )

    $logPath = Join-Path $PSScriptRoot 'mklink.log'
    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    Add-Content -LiteralPath $logPath -Value "[$timestamp] $Message"
}

function Get-MklinkPendingSource {
    if (-not (Test-Path -LiteralPath $script:MklinkRegistryPath)) {
        return $null
    }

    $props = Get-ItemProperty -LiteralPath $script:MklinkRegistryPath -Name 'SourcePath' -ErrorAction SilentlyContinue
    if (-not $props.SourcePath) {
        return $null
    }

    return [string]$props.SourcePath
}

function Set-MklinkPendingSource {
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$SourcePath
    )

    $resolved = (Resolve-Path -LiteralPath $SourcePath -ErrorAction Stop).Path
    $item = Get-Item -LiteralPath $resolved -Force -ErrorAction Stop
    if (-not $item.PSIsContainer) {
        throw "Source path is not a folder: $resolved"
    }

    if (-not (Test-Path -LiteralPath $script:MklinkRegistryPath)) {
        New-Item -Path $script:MklinkRegistryPath -Force | Out-Null
    }

    Remove-ItemProperty -LiteralPath $script:MklinkRegistryPath -Name * -ErrorAction SilentlyContinue
    New-ItemProperty -LiteralPath $script:MklinkRegistryPath -Name 'SourcePath' -Value $resolved -Force | Out-Null
    Write-MklinkLog "Pending source set: $resolved"

    return $resolved
}

function Clear-MklinkPendingSource {
    if (Test-Path -LiteralPath $script:MklinkRegistryPath) {
        Remove-ItemProperty -LiteralPath $script:MklinkRegistryPath -Name * -ErrorAction SilentlyContinue
    }

    Write-MklinkLog 'Pending source cleared'
}

function Get-MklinkItemInfo {
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Path
    )

    $item = Get-Item -LiteralPath $Path -Force -ErrorAction Stop
    $target = ''
    if ($item.Target) {
        $target = ($item.Target -join '; ')
    }

    [PSCustomObject]@{
        Path     = $item.FullName
        Name     = $item.Name
        IsFolder = $item.PSIsContainer
        LinkType = $item.LinkType
        Target   = $target
        IsJunction = ($item.PSIsContainer -and $item.LinkType -eq 'Junction')
        TargetExists = ($target -and (Test-Path -LiteralPath $target -ErrorAction SilentlyContinue))
    }
}

function Assert-MklinkJunction {
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$LinkPath
    )

    $info = Get-MklinkItemInfo -Path $LinkPath
    if (-not $info.IsJunction) {
        throw "Path is not a junction: $LinkPath"
    }

    if (-not $info.Target) {
        throw "Junction target could not be resolved: $LinkPath"
    }

    if ($info.Target -like '*;*') {
        throw "Junction has multiple targets and cannot be managed safely: $LinkPath"
    }

    return $info
}

function New-MklinkJunctionMove {
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$SourcePath,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$TargetDirectory
    )

    $source = (Resolve-Path -LiteralPath $SourcePath -ErrorAction Stop).Path
    $targetDir = (Resolve-Path -LiteralPath $TargetDirectory -ErrorAction Stop).Path
    $sourceItem = Get-Item -LiteralPath $source -Force -ErrorAction Stop
    $targetItem = Get-Item -LiteralPath $targetDir -Force -ErrorAction Stop

    if (-not $sourceItem.PSIsContainer) {
        throw "Source path is not a folder: $source"
    }
    if (-not $targetItem.PSIsContainer) {
        throw "Target path is not a folder: $targetDir"
    }
    if ($sourceItem.LinkType) {
        throw "Source is already a reparse point: $source"
    }

    $newLocation = Join-Path $targetDir $sourceItem.Name
    if (Test-Path -LiteralPath $newLocation) {
        throw "Folder already exists at target: $newLocation"
    }

    Write-MklinkLog "Create requested: $source -> $newLocation"
    Move-Item -LiteralPath $source -Destination $newLocation -Force -ErrorAction Stop

    try {
        $cmdOutput = & cmd.exe /d /c mklink /J "`"$source`"" "`"$newLocation`"" 2>&1
        if ($LASTEXITCODE -ne 0) {
            throw "mklink failed with exit code $LASTEXITCODE. $($cmdOutput -join ' ')"
        }
    }
    catch {
        if ((Test-Path -LiteralPath $newLocation) -and -not (Test-Path -LiteralPath $source)) {
            Move-Item -LiteralPath $newLocation -Destination $source -Force -ErrorAction SilentlyContinue
        }
        throw
    }

    Clear-MklinkPendingSource
    Write-MklinkLog "Created junction: $source -> $newLocation"

    [PSCustomObject]@{
        LinkPath   = $source
        TargetPath = $newLocation
    }
}

function Revert-MklinkJunction {
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$LinkPath
    )

    $info = Assert-MklinkJunction -LinkPath $LinkPath
    $target = $info.Target

    if (-not (Test-Path -LiteralPath $target)) {
        throw "Target folder does not exist: $target"
    }

    Write-MklinkLog "Revert requested: $($info.Path) <- $target"
    Remove-Item -LiteralPath $info.Path -Force -ErrorAction Stop

    try {
        Move-Item -LiteralPath $target -Destination $info.Path -Force -ErrorAction Stop
    }
    catch {
        $cmdOutput = & cmd.exe /d /c mklink /J "`"$($info.Path)`"" "`"$target`"" 2>&1
        Write-MklinkLog "Revert failed, attempted junction restore. Output: $($cmdOutput -join ' ')"
        throw
    }

    Write-MklinkLog "Reverted junction: $($info.Path)"

    [PSCustomObject]@{
        RestoredPath = $info.Path
        OldTarget    = $target
    }
}

function Move-MklinkJunctionTarget {
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$LinkPath,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$NewTargetDirectory
    )

    $info = Assert-MklinkJunction -LinkPath $LinkPath
    $oldTarget = $info.Target
    $newTargetDir = (Resolve-Path -LiteralPath $NewTargetDirectory -ErrorAction Stop).Path
    $newTargetItem = Get-Item -LiteralPath $newTargetDir -Force -ErrorAction Stop
    if (-not $newTargetItem.PSIsContainer) {
        throw "New target path is not a folder: $newTargetDir"
    }
    if (-not (Test-Path -LiteralPath $oldTarget)) {
        throw "Current target folder does not exist: $oldTarget"
    }

    $newTarget = Join-Path $newTargetDir $info.Name
    if (Test-Path -LiteralPath $newTarget) {
        throw "Folder already exists at new target: $newTarget"
    }

    Write-MklinkLog "Move target requested: $($info.Path) from $oldTarget to $newTarget"
    Move-Item -LiteralPath $oldTarget -Destination $newTarget -Force -ErrorAction Stop

    try {
        Remove-Item -LiteralPath $info.Path -Force -ErrorAction Stop
        $cmdOutput = & cmd.exe /d /c mklink /J "`"$($info.Path)`"" "`"$newTarget`"" 2>&1
        if ($LASTEXITCODE -ne 0) {
            throw "mklink failed with exit code $LASTEXITCODE. $($cmdOutput -join ' ')"
        }
    }
    catch {
        Write-MklinkLog "Move target failed, attempting rollback for: $($info.Path)"

        if (-not (Test-Path -LiteralPath $oldTarget) -and (Test-Path -LiteralPath $newTarget)) {
            Move-Item -LiteralPath $newTarget -Destination $oldTarget -Force -ErrorAction SilentlyContinue
        }

        $linkExists = $false
        try {
            $null = Get-Item -LiteralPath $info.Path -Force -ErrorAction Stop
            $linkExists = $true
        }
        catch {
            $linkExists = $false
        }

        if (-not $linkExists -and (Test-Path -LiteralPath $oldTarget)) {
            & cmd.exe /d /c mklink /J "`"$($info.Path)`"" "`"$oldTarget`"" | Out-Null
        }

        throw
    }

    Write-MklinkLog "Moved junction target: $($info.Path) -> $newTarget"

    [PSCustomObject]@{
        LinkPath      = $info.Path
        OldTargetPath = $oldTarget
        NewTargetPath = $newTarget
    }
}

function Get-UserJunctions {
    $scanPaths = @("$env:USERPROFILE")

    $excludePatterns = @(
        'node_modules', '.pnpm', 'AppData\Local\Application Data',
        'AppData\Local\History', 'AppData\Local\Temporary Internet Files'
    )

    $systemJunctions = @(
        'Application Data', 'Cookies', 'Local Settings', 'My Documents',
        'NetHood', 'PrintHood', 'Recent', 'SendTo', 'Start Menu', 'Templates'
    )

    $results = [System.Collections.Generic.List[PSCustomObject]]::new()

    foreach ($root in $scanPaths) {
        if (-not (Test-Path -LiteralPath $root)) { continue }

        $items = Get-ChildItem -LiteralPath $root -Recurse -Depth 4 -Force `
            -ErrorAction SilentlyContinue -Attributes ReparsePoint |
            Where-Object { $_.LinkType -eq 'Junction' }

        foreach ($item in $items) {
            $skip = $false
            $itemName = $item.Name
            $full = $item.FullName

            if ($itemName -in $systemJunctions) { continue }

            foreach ($pat in $excludePatterns) {
                if ($full -like "*$pat*") { $skip = $true; break }
            }
            if ($skip) { continue }

            $target = ''
            $valid  = $false
            try {
                $resolved = Get-Item -LiteralPath $full -Force -ErrorAction Stop
                if ($resolved.Target) {
                    $target = ($resolved.Target -join '; ')
                    $valid  = Test-Path -LiteralPath $target -ErrorAction SilentlyContinue
                }
            } catch {
                $target = '(inaccessible)'
            }

            $category = 'Other'
            if ($full -match 'AppData\\Roaming') {
                $category = 'AppData (Roaming)'
            }
            elseif ($full -match 'AppData\\Local') {
                $category = 'AppData (Local)'
            }
            elseif ($full -match '\\Users\\[^\\]+\\\.') {
                $category = 'Dotfiles / Config'
            }
            elseif ($full -match '\\Users\\[^\\]+\\[^\\\.]+$') {
                $category = 'User Profile'
            }

            $results.Add([PSCustomObject]@{
                Name     = $itemName
                Link     = $full
                Target   = $target
                Valid    = $valid
                Category = $category
            })
        }
    }

    return $results | Sort-Object Category, Name
}
