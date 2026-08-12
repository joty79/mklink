#Requires -Version 7

[CmdletBinding()]
param(
    [string]$CorePath = (Join-Path $PSScriptRoot '..\MklinkCore.ps1')
)

$ErrorActionPreference = 'Stop'
$testId = [guid]::NewGuid().ToString('N')
$cRoot = Join-Path $env:TEMP "mklink-test-$testId"
$dRoot = "D:\Users\joty79\Temp\mklink-test-$testId"
$testRegistryParent = 'HKCU:\Software\CodexMklinkTests'
$testRegistry = Join-Path $testRegistryParent $testId

$resolvedCorePath = (Resolve-Path -LiteralPath $CorePath -ErrorAction Stop).Path
. $resolvedCorePath
$script:MklinkRegistryPath = $testRegistry

function Write-MklinkLog {
    param([string]$Message)

    $null = $Message
}

try {
    $existingTarget = Join-Path $dRoot 'ExistingFolder'
    $existingLinkParent = Join-Path $cRoot 'ExistingLinkParent'
    $moveSource = Join-Path $cRoot 'MoveFolder'
    $moveDestination = Join-Path $dRoot 'MoveDestination'

    $null = New-Item -ItemType Directory -Path $existingTarget -Force
    $null = New-Item -ItemType Directory -Path $existingLinkParent -Force
    $null = New-Item -ItemType Directory -Path $moveSource -Force
    $null = New-Item -ItemType Directory -Path $moveDestination -Force
    Set-Content -LiteralPath (Join-Path $existingTarget 'sentinel.txt') -Value 'existing-target-data' -Encoding utf8
    Set-Content -LiteralPath (Join-Path $moveSource 'sentinel.txt') -Value 'move-source-data' -Encoding utf8

    $null = Set-MklinkPendingExistingTarget -TargetPath $existingTarget
    $pendingTarget = Get-MklinkPendingSelection
    if ($pendingTarget.Mode -ne 'ExistingTarget' -or $pendingTarget.Path -ne $existingTarget) {
        throw 'ExistingTarget pending selection did not round-trip.'
    }

    $existingResult = New-MklinkJunctionForExistingTarget `
        -TargetPath $pendingTarget.Path `
        -LinkParentDirectory $existingLinkParent
    $existingLinkItem = Get-Item -LiteralPath $existingResult.LinkPath -Force
    if ($existingLinkItem.LinkType -ne 'Junction') {
        throw 'ExistingTarget result is not a Junction.'
    }
    if ((Get-Content -LiteralPath (Join-Path $existingResult.LinkPath 'sentinel.txt') -Raw).Trim() -ne 'existing-target-data') {
        throw 'ExistingTarget Junction did not expose target data.'
    }
    if (-not (Test-Path -LiteralPath $existingTarget)) {
        throw 'Existing target was moved or removed.'
    }
    if ($null -ne (Get-MklinkPendingSelection)) {
        throw 'Pending selection was not cleared after ExistingTarget success.'
    }

    $collisionRejected = $false
    try {
        $null = New-MklinkJunctionForExistingTarget `
            -TargetPath $existingTarget `
            -LinkParentDirectory $existingLinkParent
    }
    catch {
        if ($_.Exception.Message -like '*link path already exists*') {
            $collisionRejected = $true
        }
        else {
            throw
        }
    }
    if (-not $collisionRejected) {
        throw 'Existing link-path collision was not rejected.'
    }

    $null = Set-MklinkPendingSource -SourcePath $moveSource
    $pendingMove = Get-MklinkPendingSelection
    if ($pendingMove.Mode -ne 'MoveSource' -or $pendingMove.Path -ne $moveSource) {
        throw 'MoveSource pending selection did not round-trip.'
    }

    $moveResult = New-MklinkJunctionMove `
        -SourcePath $pendingMove.Path `
        -TargetDirectory $moveDestination
    $moveLinkItem = Get-Item -LiteralPath $moveResult.LinkPath -Force
    if ($moveLinkItem.LinkType -ne 'Junction') {
        throw 'MoveSource result is not a Junction.'
    }
    if ((Get-Content -LiteralPath (Join-Path $moveResult.LinkPath 'sentinel.txt') -Raw).Trim() -ne 'move-source-data') {
        throw 'MoveSource Junction did not expose moved data.'
    }
    if (-not (Test-Path -LiteralPath $moveResult.TargetPath)) {
        throw 'MoveSource target was not created.'
    }

    [PSCustomObject]@{
        ExistingTargetMode          = $pendingTarget.Mode
        ExistingTargetLinkType      = $existingLinkItem.LinkType
        ExistingTargetStayedInPlace = Test-Path -LiteralPath $existingTarget
        CollisionRejected           = $collisionRejected
        MoveSourceMode              = $pendingMove.Mode
        MoveSourceLinkType          = $moveLinkItem.LinkType
        MoveSourceTargetCreated     = Test-Path -LiteralPath $moveResult.TargetPath
        Result                      = 'PASS'
    }
}
finally {
    $candidateLinks = @(
        (Join-Path $cRoot 'ExistingLinkParent\ExistingFolder'),
        (Join-Path $cRoot 'MoveFolder')
    )
    foreach ($candidateLink in $candidateLinks) {
        $candidateItem = Get-Item -LiteralPath $candidateLink -Force -ErrorAction SilentlyContinue
        if ($candidateItem -and $candidateItem.LinkType -eq 'Junction') {
            Remove-Item -LiteralPath $candidateLink -Force -ErrorAction Stop
        }
    }

    foreach ($root in @($cRoot, $dRoot)) {
        $resolvedRoot = [IO.Path]::GetFullPath($root)
        if ($resolvedRoot -notlike "*mklink-test-$testId") {
            throw "Unsafe cleanup path: $resolvedRoot"
        }
        if (Test-Path -LiteralPath $resolvedRoot) {
            Remove-Item -LiteralPath $resolvedRoot -Recurse -Force -ErrorAction Stop
        }
    }

    if (Test-Path -LiteralPath $testRegistry) {
        Remove-Item -LiteralPath $testRegistry -Recurse -Force -ErrorAction Stop
    }
    if ((Test-Path -LiteralPath $testRegistryParent) -and
        @(Get-ChildItem -LiteralPath $testRegistryParent -ErrorAction Stop).Count -eq 0) {
        Remove-Item -LiteralPath $testRegistryParent -Force -ErrorAction Stop
    }
}
