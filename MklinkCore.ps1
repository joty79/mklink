#Requires -Version 7

$script:MklinkRegistryPath = 'HKCU:\RCWM\mklink'

function Get-MklinkDataPath {
    param(
        [string]$SubFolder,
        [string]$FileName
    )

    $dataDir = Join-Path $PSScriptRoot 'data'
    if ($SubFolder) {
        $dataDir = Join-Path $dataDir $SubFolder
    }

    if (-not (Test-Path -LiteralPath $dataDir)) {
        $null = New-Item -ItemType Directory -Path $dataDir -Force -ErrorAction SilentlyContinue
    }

    if ($FileName) {
        return Join-Path $dataDir $FileName
    }
    return $dataDir
}

function Write-MklinkLog {
    param(
        [Parameter(Mandatory)]
        [string]$Message
    )

    $logPath = Get-MklinkDataPath -SubFolder 'logs' -FileName 'mklink.log'
    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    Add-Content -LiteralPath $logPath -Value "[$timestamp] $Message"
}

function Get-MklinkPendingSelection {
    if (-not (Test-Path -LiteralPath $script:MklinkRegistryPath)) {
        return $null
    }

    $props = Get-ItemProperty -LiteralPath $script:MklinkRegistryPath -ErrorAction SilentlyContinue
    if (-not $props.SourcePath) {
        return $null
    }

    $mode = [string]$props.PendingMode
    if ($mode -notin @('MoveSource', 'ExistingTarget')) {
        $mode = 'MoveSource'
    }

    [PSCustomObject]@{
        Path = [string]$props.SourcePath
        Mode = $mode
    }
}

function Get-MklinkPendingSource {
    $selection = Get-MklinkPendingSelection
    if (-not $selection) {
        return $null
    }

    return $selection.Path
}

function Set-MklinkPendingSelection {
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$FolderPath,

        [Parameter(Mandatory)]
        [ValidateSet('MoveSource', 'ExistingTarget')]
        [string]$Mode
    )

    $resolved = (Resolve-Path -LiteralPath $FolderPath -ErrorAction Stop).Path
    $item = Get-Item -LiteralPath $resolved -Force -ErrorAction Stop
    if (-not $item.PSIsContainer) {
        throw "Selected path is not a folder: $resolved"
    }
    if ($item.LinkType) {
        throw "Selected folder is already a reparse point: $resolved"
    }

    if (-not (Test-Path -LiteralPath $script:MklinkRegistryPath)) {
        New-Item -Path $script:MklinkRegistryPath -Force | Out-Null
    }

    Remove-ItemProperty `
        -LiteralPath $script:MklinkRegistryPath `
        -Name 'SourcePath', 'PendingMode' `
        -ErrorAction SilentlyContinue
    New-ItemProperty -LiteralPath $script:MklinkRegistryPath -Name 'SourcePath' -Value $resolved -Force | Out-Null
    New-ItemProperty -LiteralPath $script:MklinkRegistryPath -Name 'PendingMode' -Value $Mode -Force | Out-Null
    Write-MklinkLog "Pending selection set: mode=$Mode; path=$resolved"

    return Get-MklinkPendingSelection
}

function Set-MklinkPendingSource {
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$SourcePath
    )

    return Set-MklinkPendingSelection -FolderPath $SourcePath -Mode 'MoveSource'
}

function Set-MklinkPendingExistingTarget {
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$TargetPath
    )

    return Set-MklinkPendingSelection -FolderPath $TargetPath -Mode 'ExistingTarget'
}

function Clear-MklinkPendingSource {
    if (Test-Path -LiteralPath $script:MklinkRegistryPath) {
        Remove-ItemProperty `
            -LiteralPath $script:MklinkRegistryPath `
            -Name 'SourcePath', 'PendingMode' `
            -ErrorAction SilentlyContinue
    }

    Write-MklinkLog 'Pending selection cleared'
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

function New-MklinkJunctionForExistingTarget {
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$TargetPath,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$LinkParentDirectory
    )

    $target = (Resolve-Path -LiteralPath $TargetPath -ErrorAction Stop).Path
    $linkParent = (Resolve-Path -LiteralPath $LinkParentDirectory -ErrorAction Stop).Path
    $targetItem = Get-Item -LiteralPath $target -Force -ErrorAction Stop
    $linkParentItem = Get-Item -LiteralPath $linkParent -Force -ErrorAction Stop

    if (-not $targetItem.PSIsContainer) {
        throw "Existing target is not a folder: $target"
    }
    if ($targetItem.LinkType) {
        throw "Existing target is already a reparse point: $target"
    }
    if (-not $linkParentItem.PSIsContainer) {
        throw "Junction parent path is not a folder: $linkParent"
    }

    $targetName = Split-Path -Path $target -Leaf
    if (-not $targetName) {
        throw "Cannot create a named junction for the root path: $target"
    }

    $linkPath = Join-Path $linkParent $targetName
    $existingItem = Get-Item -LiteralPath $linkPath -Force -ErrorAction SilentlyContinue
    if ($null -ne $existingItem) {
        throw "Cannot create junction because the link path already exists: $linkPath"
    }

    Write-MklinkLog "Existing-target junction requested: $linkPath -> $target"
    $null = New-Item -ItemType Junction -Path $linkPath -Target $target -ErrorAction Stop

    Clear-MklinkPendingSource
    Write-MklinkLog "Created junction for existing target: $linkPath -> $target"

    [PSCustomObject]@{
        LinkPath   = $linkPath
        TargetPath = $target
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

function Export-MklinkSnapshot {
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    $junctions = Get-UserJunctions
    $serialized = [System.Collections.Generic.List[PSCustomObject]]::new()
    $userProfile = [regex]::Escape($env:USERPROFILE)

    foreach ($j in $junctions) {
        # Replace UserProfile with placeholder %USERPROFILE% case-insensitively
        $linkPlaceholder = $j.Link -ireplace $userProfile, '%USERPROFILE%'
        $targetPlaceholder = $j.Target -ireplace $userProfile, '%USERPROFILE%'

        $serialized.Add([PSCustomObject]@{
            Name     = $j.Name
            Link     = $linkPlaceholder
            Target   = $targetPlaceholder
            Category = $j.Category
        })
    }

    # Convert to JSON with pretty print
    $json = ConvertTo-Json -InputObject $serialized -Depth 5
    Set-Content -LiteralPath $Path -Value $json -Encoding utf8 -Force
    Write-MklinkLog "Snapshot exported to: $Path ($($serialized.Count) items)"
}

function Import-MklinkSnapshot {
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "Snapshot file not found: $Path"
    }

    $content = Get-Content -LiteralPath $Path -Raw -ErrorAction Stop
    $data = ConvertFrom-Json -InputObject $content -ErrorAction Stop

    $results = [System.Collections.Generic.List[PSCustomObject]]::new()
    foreach ($item in $data) {
        # Replace placeholder with current user profile path
        $resolvedLink = $item.Link -replace '%USERPROFILE%', $env:USERPROFILE
        $resolvedTarget = $item.Target -replace '%USERPROFILE%', $env:USERPROFILE

        $results.Add([PSCustomObject]@{
            Name     = $item.Name
            Link     = $resolvedLink
            Target   = $resolvedTarget
            Category = $item.Category
            OriginalLink = $item.Link
            OriginalTarget = $item.Target
        })
    }

    Write-MklinkLog "Snapshot imported from: $Path ($($results.Count) items)"
    return $results
}

function Restore-MklinkJunction {
    param(
        [Parameter(Mandatory)]
        [string]$LinkPath,

        [Parameter(Mandatory)]
        [string]$TargetPath,

        [switch]$OverwriteBackup
    )

    # Ensure target directory exists
    if (-not (Test-Path -LiteralPath $TargetPath)) {
        throw "Target folder does not exist: $TargetPath"
    }

    # Ensure parent directory of the link path exists
    $parentDir = Split-Path -Path $LinkPath -Parent
    if ($parentDir -and -not (Test-Path -LiteralPath $parentDir)) {
        $null = New-Item -ItemType Directory -Path $parentDir -Force -ErrorAction Stop
    }

    # Check if something already exists at LinkPath
    if (Test-Path -LiteralPath $LinkPath) {
        # Get type of existing item
        $item = Get-Item -LiteralPath $LinkPath -Force
        
        if ($item.LinkType -eq 'Junction') {
            # It's already a junction.
            $currentInfo = Get-MklinkItemInfo -Path $LinkPath
            if ($currentInfo.Target -eq $TargetPath) {
                # It already points to the correct target, nothing to do!
                Write-MklinkLog "Junction already exists and is correct: $LinkPath -> $TargetPath"
                return [PSCustomObject]@{ Status = 'AlreadyExists'; Message = 'Junction already exists and points to the correct target.' }
            } else {
                # It points to a different target. Remove old junction and recreate.
                Write-MklinkLog "Removing existing junction pointing to different target: $LinkPath ($($currentInfo.Target) -> $TargetPath)"
                Remove-Item -LiteralPath $LinkPath -Force -ErrorAction Stop
            }
        }
        elseif ($item.PSIsContainer) {
            # It's a normal directory. We need to back it up.
            $backupPath = "${LinkPath}_backup"
            if (Test-Path -LiteralPath $backupPath) {
                if ($OverwriteBackup) {
                    Write-MklinkLog "OverwriteBackup set. Removing old backup directory: $backupPath"
                    Remove-Item -LiteralPath $backupPath -Recurse -Force -ErrorAction Stop
                } else {
                    return [PSCustomObject]@{ Status = 'BackupConflict'; BackupPath = $backupPath; Message = "A backup folder already exists at: $backupPath" }
                }
            }

            Write-MklinkLog "Backing up normal folder at LinkPath: $LinkPath -> $backupPath"
            Move-Item -LiteralPath $LinkPath -Destination $backupPath -Force -ErrorAction Stop
        }
        else {
            # It's a file or something else.
            $backupPath = "${LinkPath}_backup"
            if (Test-Path -LiteralPath $backupPath) {
                if ($OverwriteBackup) {
                    Remove-Item -LiteralPath $backupPath -Force -ErrorAction Stop
                } else {
                    return [PSCustomObject]@{ Status = 'BackupConflict'; BackupPath = $backupPath; Message = "A backup file already exists at: $backupPath" }
                }
            }
            Write-MklinkLog "Backing up file at LinkPath: $LinkPath -> $backupPath"
            Move-Item -LiteralPath $LinkPath -Destination $backupPath -Force -ErrorAction Stop
        }
    }

    # Now create the junction
    Write-MklinkLog "Creating restored junction: $LinkPath -> $TargetPath"
    $cmdOutput = & cmd.exe /d /c mklink /J "`"$LinkPath`"" "`"$TargetPath`"" 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "mklink failed with exit code $LASTEXITCODE. $($cmdOutput -join ' ')"
    }

    Write-MklinkLog "Successfully restored junction: $LinkPath -> $TargetPath"
    return [PSCustomObject]@{ Status = 'Success'; Message = 'Junction created successfully.' }
}
