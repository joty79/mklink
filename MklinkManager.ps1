#Requires -Version 7
<#
.SYNOPSIS
    mklink Manager - WinForms GUI to view and manage active junctions/symlinks.
.DESCRIPTION
    Scans user directories for active junctions (excluding system/node_modules noise)
    and displays them in a clean, modern WinForms interface with categorized groups.
#>

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# ─────────────────────────────────────────────────────────────────
# DPI Awareness — must be called BEFORE any WinForms handles are created
# ─────────────────────────────────────────────────────────────────
Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public class DpiHelper {
    [DllImport("user32.dll")]
    public static extern bool SetProcessDPIAware();
}
'@
[void][DpiHelper]::SetProcessDPIAware()

# Compute scale factor from current screen DPI
[System.Windows.Forms.Application]::EnableVisualStyles()
$screen = [System.Windows.Forms.Screen]::PrimaryScreen
$g = [System.Drawing.Graphics]::FromHwnd([System.IntPtr]::Zero)
$script:dpiScale = $g.DpiX / 96.0
$g.Dispose()

function Scale([int]$px) { return [int]($px * $script:dpiScale) }

. "$PSScriptRoot\MklinkCore.ps1"

# ─────────────────────────────────────────────────────────────────
# Theme / Colors
# ─────────────────────────────────────────────────────────────────
$script:clrBg         = [System.Drawing.Color]::FromArgb(24, 24, 32)
$script:clrPanel      = [System.Drawing.Color]::FromArgb(32, 33, 44)
$script:clrHeader     = [System.Drawing.Color]::FromArgb(40, 42, 56)
$script:clrAccent     = [System.Drawing.Color]::FromArgb(99, 130, 255)
$script:clrAccentDim  = [System.Drawing.Color]::FromArgb(60, 80, 180)
$script:clrText       = [System.Drawing.Color]::FromArgb(220, 225, 240)
$script:clrTextDim    = [System.Drawing.Color]::FromArgb(140, 148, 170)
$script:clrGreen      = [System.Drawing.Color]::FromArgb(80, 200, 120)
$script:clrRed        = [System.Drawing.Color]::FromArgb(220, 80, 80)
$script:clrOrange     = [System.Drawing.Color]::FromArgb(240, 170, 60)
$script:clrRowAlt     = [System.Drawing.Color]::FromArgb(28, 29, 38)
$script:clrRowHover   = [System.Drawing.Color]::FromArgb(45, 48, 65)
$script:clrBorder     = [System.Drawing.Color]::FromArgb(55, 58, 75)

$script:fontFamily    = 'Segoe UI'
$script:fontTitle     = [System.Drawing.Font]::new($script:fontFamily, 14, [System.Drawing.FontStyle]::Bold)
$script:fontSubtitle  = [System.Drawing.Font]::new($script:fontFamily, 9, [System.Drawing.FontStyle]::Regular)
$script:fontHeader    = [System.Drawing.Font]::new($script:fontFamily, 9, [System.Drawing.FontStyle]::Bold)
$script:fontCell      = [System.Drawing.Font]::new($script:fontFamily, 9, [System.Drawing.FontStyle]::Regular)
$script:fontButton    = [System.Drawing.Font]::new($script:fontFamily, 9, [System.Drawing.FontStyle]::Bold)
$script:fontStatus    = [System.Drawing.Font]::new($script:fontFamily, 8.5, [System.Drawing.FontStyle]::Regular)
$script:fontBold      = [System.Drawing.Font]::new($script:fontFamily, 9, [System.Drawing.FontStyle]::Bold)

# ─────────────────────────────────────────────────────────────────
# Build Form
# ─────────────────────────────────────────────────────────────────

$script:form = [System.Windows.Forms.Form]@{
    Text            = 'mklink Manager'
    Size            = [System.Drawing.Size]::new(1050, 680)
    MinimumSize     = [System.Drawing.Size]::new(850, 550)
    StartPosition   = 'CenterScreen'
    BackColor       = $script:clrBg
    ForeColor       = $script:clrText
    Font            = $script:fontCell
    FormBorderStyle = 'Sizable'
}

# Double-buffer via reflection for flicker-free
$prop = $script:form.GetType().GetProperty('DoubleBuffered', [System.Reflection.BindingFlags]'Instance,NonPublic')
$prop.SetValue($script:form, $true, $null)

# ── Title Bar Panel ──
$script:pnlTitle = [System.Windows.Forms.Panel]::new()
$script:pnlTitle.Dock      = 'Top'
$script:pnlTitle.Height    = $(Scale 92)
$script:pnlTitle.BackColor = $script:clrHeader
$script:pnlTitle.Padding   = [System.Windows.Forms.Padding]::new(20, 0, 20, 0)

$lblTitle = [System.Windows.Forms.Label]::new()
$lblTitle.Text      = 'mklink Manager'
$lblTitle.Font      = $script:fontTitle
$lblTitle.ForeColor = $script:clrText
$lblTitle.AutoSize  = $true
$lblTitle.Location  = [System.Drawing.Point]::new($(Scale 20), $(Scale 12))
$script:pnlTitle.Controls.Add($lblTitle)

$lblSubtitle = [System.Windows.Forms.Label]::new()
$lblSubtitle.Text      = 'Active Junctions & Symbolic Links'
$lblSubtitle.Font      = $script:fontSubtitle
$lblSubtitle.ForeColor = $script:clrTextDim
$lblSubtitle.AutoSize  = $true
$lblSubtitle.Location  = [System.Drawing.Point]::new($(Scale 20), $(Scale 40))
$script:pnlTitle.Controls.Add($lblSubtitle)

$script:lblPending = [System.Windows.Forms.Label]::new()
$script:lblPending.Text      = 'Pending source: none'
$script:lblPending.Font      = $script:fontStatus
$script:lblPending.ForeColor = $script:clrTextDim
$script:lblPending.AutoSize  = $true
$script:lblPending.Location  = [System.Drawing.Point]::new($(Scale 20), $(Scale 62))
$script:pnlTitle.Controls.Add($script:lblPending)

# Help description label aligned below the right-side buttons
$script:lblHelp = [System.Windows.Forms.Label]::new()
$script:lblHelp.Font      = $script:fontStatus
$script:lblHelp.ForeColor = $script:clrAccent
$script:lblHelp.AutoSize  = $false
$script:lblHelp.Width     = $(Scale 650)
$script:lblHelp.Height    = $(Scale 22)
$script:lblHelp.TextAlign = 'MiddleRight'
$script:lblHelp.Anchor    = 'Top, Right'
$script:lblHelp.Text      = ''
$script:pnlTitle.Controls.Add($script:lblHelp)
$script:lblHelp.BringToFront()

function New-TitleButton {
    param(
        [Parameter(Mandatory)]
        [string]$Text,

        [Parameter(Mandatory)]
        [int]$Width,

        [System.Drawing.Color]$BackColor = $script:clrAccent
    )

    $button = [System.Windows.Forms.Button]::new()
    $button.Text      = $Text
    $button.Font      = $script:fontButton
    $button.Size      = [System.Drawing.Size]::new($(Scale $Width), $(Scale 34))
    $button.FlatStyle = 'Flat'
    $button.BackColor = $BackColor
    $button.ForeColor = [System.Drawing.Color]::White
    $button.Cursor    = [System.Windows.Forms.Cursors]::Hand
    $button.Anchor    = 'Top, Right'
    $button.FlatAppearance.BorderSize = 0
    $script:pnlTitle.Controls.Add($button)
    return $button
}

# Live view buttons
$script:btnCreate       = New-TitleButton -Text 'Create' -Width 86
$script:btnRevert       = New-TitleButton -Text 'Revert' -Width 86 -BackColor $script:clrOrange
$script:btnChange       = New-TitleButton -Text 'Change' -Width 86 -BackColor $script:clrAccentDim
$script:btnClearPending = New-TitleButton -Text 'Clear Source' -Width 110 -BackColor $script:clrBorder
$script:btnRefresh      = New-TitleButton -Text 'Refresh' -Width 86

# Snapshot Panel Buttons
$script:btnLoadSnapshot = New-TitleButton -Text 'Load Snapshot' -Width 110
$script:btnSaveSnapshot = New-TitleButton -Text 'Save Snapshot' -Width 110 -BackColor $script:clrAccentDim
$script:btnApplyChecked = New-TitleButton -Text 'Apply Checked' -Width 110 -BackColor $script:clrGreen
$script:btnRedirect     = New-TitleButton -Text 'Global Redirect' -Width 120 -BackColor $script:clrOrange
$script:btnToggleAll    = New-TitleButton -Text 'Check All' -Width 90 -BackColor $script:clrBorder
$script:btnCaptureLive  = New-TitleButton -Text 'Capture Live' -Width 100 -BackColor $script:clrAccentDim

# Hide snapshot buttons initially
$script:btnLoadSnapshot.Visible = $false
$script:btnSaveSnapshot.Visible = $false
$script:btnApplyChecked.Visible = $false
$script:btnRedirect.Visible     = $false
$script:btnToggleAll.Visible    = $false
$script:btnCaptureLive.Visible  = $false

# Helper function to attach hover descriptions
function Add-ButtonHoverDescription {
    param(
        [Parameter(Mandatory)]
        [System.Windows.Forms.Button]$Button,
        [Parameter(Mandatory)]
        [string]$Description
    )

    $Button.Tag = $Description
    $Button.Add_MouseEnter({
        $script:lblHelp.Text = $this.Tag
    })
    $Button.Add_MouseLeave({
        $script:lblHelp.Text = ''
    })
}

# Attach descriptions
Add-ButtonHoverDescription -Button $script:btnCreate -Description 'Μεταφορά του Pending Source στον προορισμό και δημιουργία Junction.'
Add-ButtonHoverDescription -Button $script:btnRevert -Description 'Κατάργηση του Junction και επαναφορά του πραγματικού φακέλου στην αρχική του θέση.'
Add-ButtonHoverDescription -Button $script:btnChange -Description 'Αλλαγή του φακέλου προορισμού (Target) για το επιλεγμένο Junction.'
Add-ButtonHoverDescription -Button $script:btnClearPending -Description 'Καθαρισμός του επιλεγμένου Pending Source από το Registry.'
Add-ButtonHoverDescription -Button $script:btnRefresh -Description 'Ανανέωση της λίστας των Live Junctions.'

Add-ButtonHoverDescription -Button $script:btnLoadSnapshot -Description 'Φόρτωση αρχείου Snapshot (JSON) από το δίσκο.'
Add-ButtonHoverDescription -Button $script:btnSaveSnapshot -Description 'Αποθήκευση των τρεχόντων junctions σε αρχείο Snapshot (JSON).'
Add-ButtonHoverDescription -Button $script:btnApplyChecked -Description 'Μαζική δημιουργία των επιλεγμένων Junctions του Snapshot.'
Add-ButtonHoverDescription -Button $script:btnRedirect -Description 'Μαζική αντικατάσταση διαδρομών (Find & Replace) στα Target Paths του Snapshot.'
Add-ButtonHoverDescription -Button $script:btnToggleAll -Description 'Επιλογή ή αποεπιλογή όλων των στοιχείων στη λίστα του Snapshot.'
Add-ButtonHoverDescription -Button $script:btnCaptureLive -Description 'Λήψη των Live Junctions του συστήματος απευθείας στη λίστα Snapshot.'

# ── Status Bar ──
$script:pnlStatus = [System.Windows.Forms.Panel]::new()
$script:pnlStatus.Dock      = 'Bottom'
$script:pnlStatus.Height    = $(Scale 32)
$script:pnlStatus.BackColor = $script:clrHeader

$script:lblStatus = [System.Windows.Forms.Label]::new()
$script:lblStatus.Font      = $script:fontStatus
$script:lblStatus.ForeColor = $script:clrTextDim
$script:lblStatus.AutoSize  = $true
$script:lblStatus.Location  = [System.Drawing.Point]::new($(Scale 20), $(Scale 8))
$script:pnlStatus.Controls.Add($script:lblStatus)

# ── DataGridView (Live) ──
$script:dgv = [System.Windows.Forms.DataGridView]::new()
$script:dgv.Dock                       = 'Fill'
$script:dgv.BackgroundColor            = $script:clrBg
$script:dgv.GridColor                  = $script:clrBorder
$script:dgv.BorderStyle                = 'None'
$script:dgv.CellBorderStyle            = 'SingleHorizontal'
$script:dgv.RowHeadersVisible          = $false
$script:dgv.AllowUserToAddRows         = $false
$script:dgv.AllowUserToDeleteRows      = $false
$script:dgv.AllowUserToResizeRows      = $false
$script:dgv.ReadOnly                   = $true
$script:dgv.SelectionMode              = 'FullRowSelect'
$script:dgv.MultiSelect                = $false
$script:dgv.EnableHeadersVisualStyles  = $false
$script:dgv.ColumnHeadersHeight        = $(Scale 38)
$script:dgv.ColumnHeadersHeightSizeMode = 'DisableResizing'
$script:dgv.RowTemplate.Height = $(Scale 36)

# Double-buffer the DGV
$dgvProp = $script:dgv.GetType().GetProperty('DoubleBuffered', [System.Reflection.BindingFlags]'Instance,NonPublic')
$dgvProp.SetValue($script:dgv, $true, $null)

# Header style
$script:dgv.ColumnHeadersDefaultCellStyle.BackColor  = $script:clrHeader
$script:dgv.ColumnHeadersDefaultCellStyle.ForeColor  = $script:clrAccent
$script:dgv.ColumnHeadersDefaultCellStyle.Font       = $script:fontHeader
$script:dgv.ColumnHeadersDefaultCellStyle.Alignment  = 'MiddleLeft'
$script:dgv.ColumnHeadersDefaultCellStyle.Padding    = [System.Windows.Forms.Padding]::new(8, 0, 0, 0)
$script:dgv.ColumnHeadersDefaultCellStyle.SelectionBackColor = $script:clrHeader
$script:dgv.ColumnHeadersDefaultCellStyle.SelectionForeColor = $script:clrAccent

# Default cell style
$script:dgv.DefaultCellStyle.BackColor          = $script:clrPanel
$script:dgv.DefaultCellStyle.ForeColor          = $script:clrText
$script:dgv.DefaultCellStyle.SelectionBackColor = $script:clrRowHover
$script:dgv.DefaultCellStyle.SelectionForeColor = $script:clrText
$script:dgv.DefaultCellStyle.Font               = $script:fontCell
$script:dgv.DefaultCellStyle.Padding            = [System.Windows.Forms.Padding]::new(8, 0, 0, 0)

# Alternating row
$script:dgv.AlternatingRowsDefaultCellStyle.BackColor          = $script:clrRowAlt
$script:dgv.AlternatingRowsDefaultCellStyle.SelectionBackColor = $script:clrRowHover

# ── Columns (Live) ──
$colStatus = [System.Windows.Forms.DataGridViewTextBoxColumn]::new()
$colStatus.HeaderText  = 'Status'
$colStatus.Name        = 'Status'
$colStatus.Width       = 70
$colStatus.MinimumWidth = 60

$colCategory = [System.Windows.Forms.DataGridViewTextBoxColumn]::new()
$colCategory.HeaderText  = 'Category'
$colCategory.Name        = 'Category'
$colCategory.Width       = 140
$colCategory.MinimumWidth = 100

$colName = [System.Windows.Forms.DataGridViewTextBoxColumn]::new()
$colName.HeaderText  = 'Name'
$colName.Name        = 'JunctionName'
$colName.Width       = 140
$colName.MinimumWidth = 100

$colLink = [System.Windows.Forms.DataGridViewTextBoxColumn]::new()
$colLink.HeaderText  = 'Junction Path'
$colLink.Name        = 'Link'
$colLink.Width       = 300
$colLink.MinimumWidth = 200

$colTarget = [System.Windows.Forms.DataGridViewTextBoxColumn]::new()
$colTarget.HeaderText  = 'Target Path'
$colTarget.Name        = 'Target'
$colTarget.Width       = 300
$colTarget.MinimumWidth = 200
$colTarget.AutoSizeMode = 'Fill'

[void]$script:dgv.Columns.Add($colStatus)
[void]$script:dgv.Columns.Add($colCategory)
[void]$script:dgv.Columns.Add($colName)
[void]$script:dgv.Columns.Add($colLink)
[void]$script:dgv.Columns.Add($colTarget)

# ── DataGridView (Snapshot) ──
$script:dgvSnapshot = [System.Windows.Forms.DataGridView]::new()
$script:dgvSnapshot.Dock                       = 'Fill'
$script:dgvSnapshot.BackgroundColor            = $script:clrBg
$script:dgvSnapshot.GridColor                  = $script:clrBorder
$script:dgvSnapshot.BorderStyle                = 'None'
$script:dgvSnapshot.CellBorderStyle            = 'SingleHorizontal'
$script:dgvSnapshot.RowHeadersVisible          = $false
$script:dgvSnapshot.AllowUserToAddRows         = $false
$script:dgvSnapshot.AllowUserToDeleteRows      = $false
$script:dgvSnapshot.AllowUserToResizeRows      = $false
$script:dgvSnapshot.ReadOnly                   = $false
$script:dgvSnapshot.SelectionMode              = 'FullRowSelect'
$script:dgvSnapshot.MultiSelect                = $false
$script:dgvSnapshot.EnableHeadersVisualStyles  = $false
$script:dgvSnapshot.ColumnHeadersHeight        = $(Scale 38)
$script:dgvSnapshot.ColumnHeadersHeightSizeMode = 'DisableResizing'
$script:dgvSnapshot.RowTemplate.Height = $(Scale 36)

# Double-buffer the Snapshot DGV
$dgvSnapProp = $script:dgvSnapshot.GetType().GetProperty('DoubleBuffered', [System.Reflection.BindingFlags]'Instance,NonPublic')
$dgvSnapProp.SetValue($script:dgvSnapshot, $true, $null)

# Header style
$script:dgvSnapshot.ColumnHeadersDefaultCellStyle.BackColor  = $script:clrHeader
$script:dgvSnapshot.ColumnHeadersDefaultCellStyle.ForeColor  = $script:clrAccent
$script:dgvSnapshot.ColumnHeadersDefaultCellStyle.Font       = $script:fontHeader
$script:dgvSnapshot.ColumnHeadersDefaultCellStyle.Alignment  = 'MiddleLeft'
$script:dgvSnapshot.ColumnHeadersDefaultCellStyle.Padding    = [System.Windows.Forms.Padding]::new(8, 0, 0, 0)
$script:dgvSnapshot.ColumnHeadersDefaultCellStyle.SelectionBackColor = $script:clrHeader
$script:dgvSnapshot.ColumnHeadersDefaultCellStyle.SelectionForeColor = $script:clrAccent

# Default cell style
$script:dgvSnapshot.DefaultCellStyle.BackColor          = $script:clrPanel
$script:dgvSnapshot.DefaultCellStyle.ForeColor          = $script:clrText
$script:dgvSnapshot.DefaultCellStyle.SelectionBackColor = $script:clrRowHover
$script:dgvSnapshot.DefaultCellStyle.SelectionForeColor = $script:clrText
$script:dgvSnapshot.DefaultCellStyle.Font               = $script:fontCell
$script:dgvSnapshot.DefaultCellStyle.Padding            = [System.Windows.Forms.Padding]::new(8, 0, 0, 0)

# Alternating row
$script:dgvSnapshot.AlternatingRowsDefaultCellStyle.BackColor          = $script:clrRowAlt
$script:dgvSnapshot.AlternatingRowsDefaultCellStyle.SelectionBackColor = $script:clrRowHover

# ── Columns (Snapshot) ──
$colSnapCheck = [System.Windows.Forms.DataGridViewCheckBoxColumn]::new()
$colSnapCheck.HeaderText = 'Apply'
$colSnapCheck.Name       = 'Check'
$colSnapCheck.Width      = 55
$colSnapCheck.ReadOnly   = $false

$colSnapStatus = [System.Windows.Forms.DataGridViewTextBoxColumn]::new()
$colSnapStatus.HeaderText  = 'Status'
$colSnapStatus.Name        = 'Status'
$colSnapStatus.Width       = 100
$colSnapStatus.ReadOnly   = $true

$colSnapCategory = [System.Windows.Forms.DataGridViewTextBoxColumn]::new()
$colSnapCategory.HeaderText  = 'Category'
$colSnapCategory.Name        = 'Category'
$colSnapCategory.Width       = 130
$colSnapCategory.ReadOnly   = $true

$colSnapName = [System.Windows.Forms.DataGridViewTextBoxColumn]::new()
$colSnapName.HeaderText  = 'Name'
$colSnapName.Name        = 'JunctionName'
$colSnapName.Width       = 130
$colSnapName.ReadOnly   = $true

$colSnapLink = [System.Windows.Forms.DataGridViewTextBoxColumn]::new()
$colSnapLink.HeaderText  = 'Junction Path'
$colSnapLink.Name        = 'Link'
$colSnapLink.Width       = 280
$colSnapLink.ReadOnly   = $true

$colSnapTarget = [System.Windows.Forms.DataGridViewTextBoxColumn]::new()
$colSnapTarget.HeaderText  = 'Target Path'
$colSnapTarget.Name        = 'Target'
$colSnapTarget.Width       = 280
$colSnapTarget.AutoSizeMode = 'Fill'
$colSnapTarget.ReadOnly   = $true

[void]$script:dgvSnapshot.Columns.Add($colSnapCheck)
[void]$script:dgvSnapshot.Columns.Add($colSnapStatus)
[void]$script:dgvSnapshot.Columns.Add($colSnapCategory)
[void]$script:dgvSnapshot.Columns.Add($colSnapName)
[void]$script:dgvSnapshot.Columns.Add($colSnapLink)
[void]$script:dgvSnapshot.Columns.Add($colSnapTarget)

# ── Snapshot state ──
$script:loadedSnapshotItems = [System.Collections.Generic.List[PSCustomObject]]::new()

function Get-SelectedJunctionRow {
    if ($script:dgv.CurrentRow) {
        return $script:dgv.CurrentRow
    }

    if ($script:dgv.SelectedRows.Count -gt 0) {
        return $script:dgv.SelectedRows[0]
    }

    return $null
}

function Get-SelectedJunctionPath {
    $row = Get-SelectedJunctionRow
    if (-not $row) {
        return $null
    }

    return [string]$row.Cells['Link'].Value
}

function Show-MklinkError {
    param(
        [Parameter(Mandatory)]
        [string]$Message
    )

    [System.Windows.Forms.MessageBox]::Show(
        $script:form,
        $Message,
        'mklink Manager',
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Error
    ) | Out-Null
    $script:lblStatus.Text = $Message
}

function Confirm-MklinkAction {
    param(
        [Parameter(Mandatory)]
        [string]$Message
    )

    $answer = [System.Windows.Forms.MessageBox]::Show(
        $script:form,
        $Message,
        'mklink Manager',
        [System.Windows.Forms.MessageBoxButtons]::YesNo,
        [System.Windows.Forms.MessageBoxIcon]::Warning
    )

    return ($answer -eq [System.Windows.Forms.DialogResult]::Yes)
}

function Select-MklinkFolder {
    param(
        [Parameter(Mandatory)]
        [string]$Description
    )

    $dialog = [System.Windows.Forms.FolderBrowserDialog]::new()
    $dialog.Description = $Description
    $dialog.ShowNewFolderButton = $true
    try {
        if ($dialog.ShowDialog($script:form) -eq [System.Windows.Forms.DialogResult]::OK) {
            return $dialog.SelectedPath
        }
        return $null
    }
    finally {
        $dialog.Dispose()
    }
}

function Update-PendingSourceStatus {
    $pending = Get-MklinkPendingSource
    if ($pending) {
        $script:lblPending.Text = "Pending source: $pending"
        $script:lblPending.ForeColor = $script:clrOrange
        $script:btnCreate.Enabled = $true
        $script:btnClearPending.Enabled = $true
    }
    else {
        $script:lblPending.Text = 'Pending source: none'
        $script:lblPending.ForeColor = $script:clrTextDim
        $script:btnCreate.Enabled = $false
        $script:btnClearPending.Enabled = $false
    }
}

function Invoke-CreateFromPendingSource {
    $source = Get-MklinkPendingSource
    if (-not $source) {
        Show-MklinkError -Message 'No pending source selected from Explorer.'
        return
    }

    $targetDir = Select-MklinkFolder -Description 'Select destination folder for the pending source'
    if (-not $targetDir) { return }

    $sourceName = Split-Path -Path $source -Leaf
    $previewTarget = Join-Path $targetDir $sourceName
    $message = "Move source:`n$source`n`nCreate junction at original path pointing to:`n$previewTarget"
    if (-not (Confirm-MklinkAction -Message $message)) { return }

    try {
        $result = New-MklinkJunctionMove -SourcePath $source -TargetDirectory $targetDir
        $script:lblStatus.Text = "Created: $($result.LinkPath) -> $($result.TargetPath)"
        Update-PendingSourceStatus
        Load-JunctionData
    }
    catch {
        Show-MklinkError -Message $_.Exception.Message
    }
}

function Invoke-RevertSelectedJunction {
    $linkPath = Get-SelectedJunctionPath
    if (-not $linkPath) {
        Show-MklinkError -Message 'Select a junction first.'
        return
    }

    try {
        $info = Assert-MklinkJunction -LinkPath $linkPath
        $message = "Revert junction:`n$($info.Path)`n`nMove target back from:`n$($info.Target)`n`nThis removes the junction and restores the real folder at the original path."
        if (-not (Confirm-MklinkAction -Message $message)) { return }

        $result = Revert-MklinkJunction -LinkPath $linkPath
        $script:lblStatus.Text = "Reverted: $($result.RestoredPath)"
        Load-JunctionData
    }
    catch {
        Show-MklinkError -Message $_.Exception.Message
    }
}

function Invoke-ChangeSelectedDestination {
    $linkPath = Get-SelectedJunctionPath
    if (-not $linkPath) {
        Show-MklinkError -Message 'Select a junction first.'
        return
    }

    try {
        $info = Assert-MklinkJunction -LinkPath $linkPath
        $newTargetDir = Select-MklinkFolder -Description 'Select the new destination parent folder'
        if (-not $newTargetDir) { return }

        $previewTarget = Join-Path $newTargetDir $info.Name
        $message = "Change destination for:`n$($info.Path)`n`nMove target from:`n$($info.Target)`n`nTo:`n$previewTarget"
        if (-not (Confirm-MklinkAction -Message $message)) { return }

        $result = Move-MklinkJunctionTarget -LinkPath $linkPath -NewTargetDirectory $newTargetDir
        $script:lblStatus.Text = "Changed target: $($result.LinkPath) -> $($result.NewTargetPath)"
        Load-JunctionData
    }
    catch {
        Show-MklinkError -Message $_.Exception.Message
    }
}

# ── Context Menu (Live) ──
$ctxMenu = [System.Windows.Forms.ContextMenuStrip]::new()
$ctxMenu.BackColor = $script:clrPanel
$ctxMenu.ForeColor = $script:clrText
$ctxMenu.Font      = $script:fontCell
$ctxMenu.ShowImageMargin = $false

$ctxOpenLink = [System.Windows.Forms.ToolStripMenuItem]::new('Open Junction Folder')
$ctxOpenLink.ForeColor = $script:clrText
$ctxOpenLink.Add_Click({
    $row = $script:dgv.CurrentRow
    if ($row) {
        $linkPath = $row.Cells['Link'].Value
        if ($linkPath -and (Test-Path -LiteralPath $linkPath)) {
            Start-Process explorer.exe -ArgumentList $linkPath
        }
    }
})

$ctxOpenTarget = [System.Windows.Forms.ToolStripMenuItem]::new('Open Target Folder')
$ctxOpenTarget.ForeColor = $script:clrText
$ctxOpenTarget.Add_Click({
    $row = $script:dgv.CurrentRow
    if ($row) {
        $targetPath = $row.Cells['Target'].Value
        if ($targetPath -and (Test-Path -LiteralPath $targetPath)) {
            Start-Process explorer.exe -ArgumentList $targetPath
        }
    }
})

$ctxCopyLink = [System.Windows.Forms.ToolStripMenuItem]::new('Copy Junction Path')
$ctxCopyLink.ForeColor = $script:clrText
$ctxCopyLink.Add_Click({
    $row = $script:dgv.CurrentRow
    if ($row) {
        [System.Windows.Forms.Clipboard]::SetText($row.Cells['Link'].Value)
        $script:lblStatus.Text = "Copied: $($row.Cells['Link'].Value)"
    }
})

$ctxCopyTarget = [System.Windows.Forms.ToolStripMenuItem]::new('Copy Target Path')
$ctxCopyTarget.ForeColor = $script:clrText
$ctxCopyTarget.Add_Click({
    $row = $script:dgv.CurrentRow
    if ($row) {
        [System.Windows.Forms.Clipboard]::SetText($row.Cells['Target'].Value)
        $script:lblStatus.Text = "Copied: $($row.Cells['Target'].Value)"
    }
})

$ctxChangeTarget = [System.Windows.Forms.ToolStripMenuItem]::new('Change Destination...')
$ctxChangeTarget.ForeColor = $script:clrText
$ctxChangeTarget.Add_Click({ Invoke-ChangeSelectedDestination })

$ctxRevert = [System.Windows.Forms.ToolStripMenuItem]::new('Revert Junction')
$ctxRevert.ForeColor = $script:clrOrange
$ctxRevert.Add_Click({ Invoke-RevertSelectedJunction })

$ctxMenu.Items.AddRange(@(
    $ctxOpenLink,
    $ctxOpenTarget,
    [System.Windows.Forms.ToolStripSeparator]::new(),
    $ctxChangeTarget,
    $ctxRevert,
    [System.Windows.Forms.ToolStripSeparator]::new(),
    $ctxCopyLink,
    $ctxCopyTarget
))
$script:dgv.ContextMenuStrip = $ctxMenu

# ── Right-click selects row ──
$script:dgv.Add_CellMouseDown({
    param($sender, $e)
    if ($e.Button -eq [System.Windows.Forms.MouseButtons]::Right -and $e.RowIndex -ge 0) {
        $script:dgv.ClearSelection()
        $script:dgv.Rows[$e.RowIndex].Selected = $true
        $script:dgv.CurrentCell = $script:dgv.Rows[$e.RowIndex].Cells[0]
    }
})

# ── Cell formatting (color the status column) ──
$script:dgv.Add_CellFormatting({
    param($sender, $e)
    if ($e.ColumnIndex -eq 0 -and $e.RowIndex -ge 0) {
        $val = $e.Value
        if ($val -eq 'OK') {
            $e.CellStyle.ForeColor = $script:clrGreen
            $e.CellStyle.SelectionForeColor = $script:clrGreen
            $e.CellStyle.Font = $script:fontBold
        }
        elseif ($val -eq 'BROKEN') {
            $e.CellStyle.ForeColor = $script:clrRed
            $e.CellStyle.SelectionForeColor = $script:clrRed
            $e.CellStyle.Font = $script:fontBold
        }
    }
    if ($e.ColumnIndex -eq 1 -and $e.RowIndex -ge 0) {
        $e.CellStyle.ForeColor = $script:clrAccent
        $e.CellStyle.SelectionForeColor = $script:clrAccent
    }
})

# ── Double-click opens junction in Explorer ──
$script:dgv.Add_CellDoubleClick({
    param($sender, $e)
    if ($e.RowIndex -ge 0) {
        $linkPath = $script:dgv.Rows[$e.RowIndex].Cells['Link'].Value
        if ($linkPath -and (Test-Path -LiteralPath $linkPath)) {
            Start-Process explorer.exe -ArgumentList $linkPath
        }
    }
})

# ── Load Data Function (Live) ──
function Load-JunctionData {
    $script:dgv.SuspendLayout()
    $script:dgv.Rows.Clear()
    $script:lblStatus.Text = 'Scanning junctions...'
    $script:form.Refresh()
    
    $junctions = Get-UserJunctions
    $okCount     = 0
    $brokenCount = 0
    
    foreach ($j in $junctions) {
        $status = if ($j.Valid) { 'OK' } else { 'BROKEN' }
        if ($j.Valid) { $okCount++ } else { $brokenCount++ }
        
        [void]$script:dgv.Rows.Add(@($status, $j.Category, $j.Name, $j.Link, $j.Target))
    }
    
    $script:dgv.ResumeLayout()
    
    $total = $junctions.Count
    $statusText = "$total junctions"
    if ($brokenCount -gt 0) {
        $statusText += "  |  $okCount valid  |  $brokenCount broken"
    } else {
        $statusText += "  |  All valid"
    }
    $script:lblStatus.Text = $statusText
    Update-PendingSourceStatus
}

# ── Snapshot Support Functions ──
function Update-SnapshotStatusText {
    $total = $script:loadedSnapshotItems.Count
    if ($total -eq 0) {
        $script:lblStatus.Text = 'No snapshot loaded.'
        return
    }
    
    $checkedCount = 0
    $missingTarget = 0
    $conflictCount = 0
    
    foreach ($row in $script:dgvSnapshot.Rows) {
        if ($row.Cells['Check'].Value) {
            $checkedCount++
        }
        $status = $row.Cells['Status'].Value
        if ($status -eq 'TARGET MISSING') {
            $missingTarget++
        }
        elseif ($status -eq 'CONFLICT') {
            $conflictCount++
        }
    }
    
    $statusText = "Snapshot: $total items  |  $checkedCount selected"
    if ($missingTarget -gt 0) {
        $statusText += "  |  $missingTarget targets missing"
    }
    if ($conflictCount -gt 0) {
        $statusText += "  |  $conflictCount conflicts"
    }
    $script:lblStatus.Text = $statusText
}

function Load-SnapshotGridData {
    $script:dgvSnapshot.SuspendLayout()
    $script:dgvSnapshot.Rows.Clear()
    
    foreach ($item in $script:loadedSnapshotItems) {
        $status = 'PENDING'
        
        # Check target path
        $targetExists = Test-Path -LiteralPath $item.Target -ErrorAction SilentlyContinue
        if (-not $targetExists) {
            $status = 'TARGET MISSING'
        }
        
        # Check link path
        if (Test-Path -LiteralPath $item.Link) {
            $linkItem = Get-Item -LiteralPath $item.Link -Force
            if ($linkItem.LinkType -eq 'Junction') {
                $info = Get-MklinkItemInfo -Path $item.Link
                if ($info.Target -eq $item.Target) {
                    $status = 'APPLIED'
                } else {
                    $status = 'CONFLICT'
                }
            } else {
                $status = 'CONFLICT'
            }
        }
        
        $defaultChecked = ($status -eq 'PENDING')
        
        $rowIndex = $script:dgvSnapshot.Rows.Add()
        $row = $script:dgvSnapshot.Rows[$rowIndex]
        $row.Cells['Check'].Value = $defaultChecked
        $row.Cells['Status'].Value = $status
        $row.Cells['Category'].Value = $item.Category
        $row.Cells['JunctionName'].Value = $item.Name
        $row.Cells['Link'].Value = $item.Link
        $row.Cells['Target'].Value = $item.Target
    }
    
    $script:dgvSnapshot.ResumeLayout()
    Update-SnapshotStatusText
}

function Show-RedirectDialog {
    $dlg = [System.Windows.Forms.Form]@{
        Text            = 'Global Redirect Target Paths'
        Size            = [System.Drawing.Size]::new(400, 200)
        StartPosition   = 'CenterParent'
        FormBorderStyle = 'FixedDialog'
        MaximizeBox     = $false
        MinimizeBox     = $false
        BackColor       = $script:clrBg
        ForeColor       = $script:clrText
        Font            = $script:fontCell
    }

    $lblFind = [System.Windows.Forms.Label]@{
        Text     = 'Find path segment:'
        Location = [System.Drawing.Point]::new($(Scale 20), $(Scale 20))
        Size     = [System.Drawing.Size]::new($(Scale 340), $(Scale 18))
    }
    $txtFind = [System.Windows.Forms.TextBox]@{
        Location = [System.Drawing.Point]::new($(Scale 20), $(Scale 40))
        Size     = [System.Drawing.Size]::new($(Scale 340), $(Scale 24))
        BackColor = $script:clrPanel
        ForeColor = $script:clrText
        BorderStyle = 'FixedSingle'
        Text      = 'D:\'
    }

    $lblReplace = [System.Windows.Forms.Label]@{
        Text     = 'Replace with:'
        Location = [System.Drawing.Point]::new($(Scale 20), $(Scale 74))
        Size     = [System.Drawing.Size]::new($(Scale 340), $(Scale 18))
    }
    $txtReplace = [System.Windows.Forms.TextBox]@{
        Location = [System.Drawing.Point]::new($(Scale 20), $(Scale 94))
        Size     = [System.Drawing.Size]::new($(Scale 340), $(Scale 24))
        BackColor = $script:clrPanel
        ForeColor = $script:clrText
        BorderStyle = 'FixedSingle'
        Text      = 'E:\'
    }

    $btnOk = [System.Windows.Forms.Button]@{
        Text      = 'Replace All'
        DialogResult = [System.Windows.Forms.DialogResult]::OK
        Location  = [System.Drawing.Point]::new($(Scale 170), $(Scale 130))
        Size      = [System.Drawing.Size]::new($(Scale 100), $(Scale 28))
        FlatStyle = 'Flat'
        BackColor = $script:clrAccent
        ForeColor = [System.Drawing.Color]::White
    }
    $btnOk.FlatAppearance.BorderSize = 0

    $btnCancel = [System.Windows.Forms.Button]@{
        Text      = 'Cancel'
        DialogResult = [System.Windows.Forms.DialogResult]::Cancel
        Location  = [System.Drawing.Point]::new($(Scale 280), $(Scale 130))
        Size      = [System.Drawing.Size]::new($(Scale 80), $(Scale 28))
        FlatStyle = 'Flat'
        BackColor = $script:clrBorder
        ForeColor = $script:clrText
    }
    $btnCancel.FlatAppearance.BorderSize = 0

    $dlg.Controls.AddRange(@($lblFind, $txtFind, $lblReplace, $txtReplace, $btnOk, $btnCancel))
    $dlg.AcceptButton = $btnOk
    $dlg.CancelButton = $btnCancel

    if ($dlg.ShowDialog($script:form) -eq [System.Windows.Forms.DialogResult]::OK) {
        $findText = $txtFind.Text
        $replaceText = $txtReplace.Text
        $dlg.Dispose()
        return [PSCustomObject]@{ Find = $findText; Replace = $replaceText }
    }
    $dlg.Dispose()
    return $null
}

# ── Cell formatting (color the snapshot status column) ──
$script:dgvSnapshot.Add_CellFormatting({
    param($sender, $e)
    if ($e.ColumnIndex -eq 1 -and $e.RowIndex -ge 0) {
        $val = $e.Value
        if ($val -eq 'APPLIED') {
            $e.CellStyle.ForeColor = $script:clrGreen
            $e.CellStyle.SelectionForeColor = $script:clrGreen
            $e.CellStyle.Font = $script:fontBold
        }
        elseif ($val -eq 'PENDING') {
            $e.CellStyle.ForeColor = $script:clrTextDim
            $e.CellStyle.SelectionForeColor = $script:clrTextDim
        }
        elseif ($val -eq 'CONFLICT') {
            $e.CellStyle.ForeColor = $script:clrOrange
            $e.CellStyle.SelectionForeColor = $script:clrOrange
            $e.CellStyle.Font = $script:fontBold
        }
        elseif ($val -like 'TARGET*') {
            $e.CellStyle.ForeColor = $script:clrRed
            $e.CellStyle.SelectionForeColor = $script:clrRed
            $e.CellStyle.Font = $script:fontBold
        }
    }
    if ($e.ColumnIndex -eq 2 -and $e.RowIndex -ge 0) {
        $e.CellStyle.ForeColor = $script:clrAccent
        $e.CellStyle.SelectionForeColor = $script:clrAccent
    }
})

# ── Cell interaction update ──
$script:dgvSnapshot.Add_CellContentClick({
    param($sender, $e)
    if ($e.ColumnIndex -eq 0 -and $e.RowIndex -ge 0) {
        $script:dgvSnapshot.CommitEdit([System.Windows.Forms.DataGridViewDataErrorContexts]::Commit)
        Update-SnapshotStatusText
    }
})

$script:dgvSnapshot.Add_CellValueChanged({
    param($sender, $e)
    if ($e.ColumnIndex -eq 0 -and $e.RowIndex -ge 0) {
        Update-SnapshotStatusText
    }
})

# ── Double-click opens target/link on Snapshot grid ──
$script:dgvSnapshot.Add_CellDoubleClick({
    param($sender, $e)
    if ($e.RowIndex -ge 0) {
        $targetPath = $script:dgvSnapshot.Rows[$e.RowIndex].Cells['Target'].Value
        if ($targetPath -and (Test-Path -LiteralPath $targetPath)) {
            Start-Process explorer.exe -ArgumentList $targetPath
        } else {
            $linkPath = $script:dgvSnapshot.Rows[$e.RowIndex].Cells['Link'].Value
            if ($linkPath -and (Test-Path -LiteralPath $linkPath)) {
                Start-Process explorer.exe -ArgumentList $linkPath
            }
        }
    }
})

# ── Context Menu (Snapshot) ──
$script:ctxSnapshotMenu = [System.Windows.Forms.ContextMenuStrip]::new()
$script:ctxSnapshotMenu.BackColor = $script:clrPanel
$script:ctxSnapshotMenu.ForeColor = $script:clrText
$script:ctxSnapshotMenu.Font      = $script:fontCell
$script:ctxSnapshotMenu.ShowImageMargin = $false

$ctxSnapApply = [System.Windows.Forms.ToolStripMenuItem]::new('Apply This Junction')
$ctxSnapApply.ForeColor = $script:clrGreen
$ctxSnapApply.Add_Click({
    $row = $script:dgvSnapshot.CurrentRow
    if (-not $row) { return }
    $link = [string]$row.Cells['Link'].Value
    $target = [string]$row.Cells['Target'].Value

    $message = "Apply junction:`n$link`n`nPointing to:`n$target"
    if (-not (Confirm-MklinkAction -Message $message)) { return }

    try {
        $result = Restore-MklinkJunction -LinkPath $link -TargetPath $target -OverwriteBackup $false
        if ($result.Status -eq 'Success' -or $result.Status -eq 'AlreadyExists') {
            $row.Cells['Status'].Value = 'APPLIED'
            $row.Cells['Check'].Value = $false
            $script:lblStatus.Text = "Successfully applied: $link"
        }
        elseif ($result.Status -eq 'BackupConflict') {
            $conflictMsg = "A backup folder already exists at:`n$($result.BackupPath)`n`nDo you want to overwrite it?"
            if (Confirm-MklinkAction -Message $conflictMsg) {
                $result2 = Restore-MklinkJunction -LinkPath $link -TargetPath $target -OverwriteBackup
                if ($result2.Status -eq 'Success' -or $result2.Status -eq 'AlreadyExists') {
                    $row.Cells['Status'].Value = 'APPLIED'
                    $row.Cells['Check'].Value = $false
                    $script:lblStatus.Text = "Successfully applied with overwrite: $link"
                }
            } else {
                $row.Cells['Status'].Value = 'CONFLICT'
            }
        }
    }
    catch {
        Show-MklinkError -Message "Failed to apply junction: $($_.Exception.Message)"
        $row.Cells['Status'].Value = 'ERROR'
    }
    Update-SnapshotStatusText
})

$ctxSnapChangeTarget = [System.Windows.Forms.ToolStripMenuItem]::new('Change Target Path (Redirect)...')
$ctxSnapChangeTarget.ForeColor = $script:clrText
$ctxSnapChangeTarget.Add_Click({
    $row = $script:dgvSnapshot.CurrentRow
    if (-not $row) { return }
    $link = [string]$row.Cells['Link'].Value
    
    $newTarget = Select-MklinkFolder -Description "Select new target folder for junction: $link"
    if ($newTarget) {
        $row.Cells['Target'].Value = $newTarget
        foreach ($item in $script:loadedSnapshotItems) {
            if ($item.Link -eq $link) {
                $item.Target = $newTarget
                break
            }
        }
        Load-SnapshotGridData
    }
})

$ctxSnapOpenLink = [System.Windows.Forms.ToolStripMenuItem]::new('Open Link Folder')
$ctxSnapOpenLink.ForeColor = $script:clrText
$ctxSnapOpenLink.Add_Click({
    $row = $script:dgvSnapshot.CurrentRow
    if ($row) {
        $linkPath = $row.Cells['Link'].Value
        if ($linkPath -and (Test-Path -LiteralPath $linkPath)) {
            Start-Process explorer.exe -ArgumentList $linkPath
        }
    }
})

$ctxSnapOpenTarget = [System.Windows.Forms.ToolStripMenuItem]::new('Open Target Folder')
$ctxSnapOpenTarget.ForeColor = $script:clrText
$ctxSnapOpenTarget.Add_Click({
    $row = $script:dgvSnapshot.CurrentRow
    if ($row) {
        $targetPath = $row.Cells['Target'].Value
        if ($targetPath -and (Test-Path -LiteralPath $targetPath)) {
            Start-Process explorer.exe -ArgumentList $targetPath
        }
    }
})

$ctxSnapRemove = [System.Windows.Forms.ToolStripMenuItem]::new('Remove from list')
$ctxSnapRemove.ForeColor = $script:clrRed
$ctxSnapRemove.Add_Click({
    $row = $script:dgvSnapshot.CurrentRow
    if (-not $row) { return }
    $link = [string]$row.Cells['Link'].Value
    
    $idx = -1
    for ($i = 0; $i -lt $script:loadedSnapshotItems.Count; $i++) {
        if ($script:loadedSnapshotItems[$i].Link -eq $link) {
            $idx = $i
            break
        }
    }
    if ($idx -ne -1) {
        $script:loadedSnapshotItems.RemoveAt($idx)
    }
    
    Load-SnapshotGridData
})

$script:ctxSnapshotMenu.Items.AddRange(@(
    $ctxSnapApply,
    $ctxSnapChangeTarget,
    [System.Windows.Forms.ToolStripSeparator]::new(),
    $ctxSnapOpenLink,
    $ctxSnapOpenTarget,
    [System.Windows.Forms.ToolStripSeparator]::new(),
    $ctxSnapRemove
))
$script:dgvSnapshot.ContextMenuStrip = $script:ctxSnapshotMenu

# Right click selects row on snapshot grid
$script:dgvSnapshot.Add_CellMouseDown({
    param($sender, $e)
    if ($e.Button -eq [System.Windows.Forms.MouseButtons]::Right -and $e.RowIndex -ge 0) {
        $script:dgvSnapshot.ClearSelection()
        $script:dgvSnapshot.Rows[$e.RowIndex].Selected = $true
        $script:dgvSnapshot.CurrentCell = $script:dgvSnapshot.Rows[$e.RowIndex].Cells[0]
    }
})

# ── Dynamic Button Positioning and Swapping ──
function Set-TitleButtonPositions {
    $right = $script:pnlTitle.ClientSize.Width - $(Scale 20)
    
    $isSnapshot = $false
    if ($script:tabControl -and $script:tabControl.SelectedIndex -eq 1) {
        $isSnapshot = $true
    }

    $liveButtons = @($script:btnRefresh, $script:btnClearPending, $script:btnChange, $script:btnRevert, $script:btnCreate)
    $snapButtons = @($script:btnLoadSnapshot, $script:btnSaveSnapshot, $script:btnApplyChecked, $script:btnRedirect, $script:btnToggleAll, $script:btnCaptureLive)
    
    foreach ($b in $liveButtons) { $b.Visible = -not $isSnapshot }
    foreach ($b in $snapButtons) { $b.Visible = $isSnapshot }

    $activeButtons = if ($isSnapshot) {
        @($script:btnLoadSnapshot, $script:btnSaveSnapshot, $script:btnApplyChecked, $script:btnRedirect, $script:btnToggleAll, $script:btnCaptureLive)
    } else {
        @($script:btnRefresh, $script:btnClearPending, $script:btnChange, $script:btnRevert, $script:btnCreate)
    }

    foreach ($button in $activeButtons) {
        $right -= $button.Width
        $button.Location = [System.Drawing.Point]::new($right, $(Scale 28))
        $right -= $(Scale 8)
    }
}

# ── Resize events ──
$script:pnlTitle.Add_Resize({
    Set-TitleButtonPositions
    if ($script:lblHelp) {
        $rightLimit = $script:pnlTitle.ClientSize.Width - $(Scale 20)
        $script:lblHelp.Location = [System.Drawing.Point]::new($rightLimit - $script:lblHelp.Width, $(Scale 62))
    }
})

# ── Event Bindings ──
$script:btnRefresh.Add_Click({ Load-JunctionData })
$script:btnCreate.Add_Click({ Invoke-CreateFromPendingSource })
$script:btnRevert.Add_Click({ Invoke-RevertSelectedJunction })
$script:btnChange.Add_Click({ Invoke-ChangeSelectedDestination })
$script:btnClearPending.Add_Click({
    Clear-MklinkPendingSource
    Update-PendingSourceStatus
    $script:lblStatus.Text = 'Pending source cleared.'
})

$script:btnSaveSnapshot.Add_Click({
    $dialog = [System.Windows.Forms.SaveFileDialog]::new()
    $dialog.InitialDirectory = Get-MklinkDataPath -SubFolder 'snapshots'
    $dialog.Filter = 'JSON Files (*.json)|*.json|All Files (*.*)|*.*'
    $dialog.Title = 'Save Junctions Snapshot'
    $dialog.FileName = "mklink_snapshot_$(Get-Date -Format 'yyyyMMdd').json"
    try {
        if ($dialog.ShowDialog($script:form) -eq [System.Windows.Forms.DialogResult]::OK) {
            Export-MklinkSnapshot -Path $dialog.FileName
            $script:lblStatus.Text = "Snapshot saved to: $(Split-Path $dialog.FileName -Leaf)"
        }
    }
    catch {
        Show-MklinkError -Message "Failed to save snapshot: $($_.Exception.Message)"
    }
    finally {
        $dialog.Dispose()
    }
})

$script:btnLoadSnapshot.Add_Click({
    $dialog = [System.Windows.Forms.OpenFileDialog]::new()
    $dialog.InitialDirectory = Get-MklinkDataPath -SubFolder 'snapshots'
    $dialog.Filter = 'JSON Files (*.json)|*.json|All Files (*.*)|*.*'
    $dialog.Title = 'Load Junctions Snapshot'
    try {
        if ($dialog.ShowDialog($script:form) -eq [System.Windows.Forms.DialogResult]::OK) {
            $items = Import-MklinkSnapshot -Path $dialog.FileName
            $script:loadedSnapshotItems.Clear()
            foreach ($item in $items) {
                $script:loadedSnapshotItems.Add($item)
            }
            $script:btnToggleAll.Text = 'Uncheck All'
            Load-SnapshotGridData
            $script:lblStatus.Text = "Loaded $(Split-Path $dialog.FileName -Leaf) with $($items.Count) items."
        }
    }
    catch {
        Show-MklinkError -Message "Failed to load snapshot: $($_.Exception.Message)"
    }
    finally {
        $dialog.Dispose()
    }
})

$script:btnToggleAll.Add_Click({
    if ($script:dgvSnapshot.Rows.Count -eq 0) { return }
    
    $currentText = $script:btnToggleAll.Text
    $newValue = $true
    if ($currentText -eq 'Check All') {
        $script:btnToggleAll.Text = 'Uncheck All'
        $newValue = $true
    } else {
        $script:btnToggleAll.Text = 'Check All'
        $newValue = $false
    }
    
    $script:dgvSnapshot.SuspendLayout()
    foreach ($row in $script:dgvSnapshot.Rows) {
        $row.Cells['Check'].Value = $newValue
    }
    $script:dgvSnapshot.ResumeLayout()
    Update-SnapshotStatusText
})

$script:btnRedirect.Add_Click({
    if ($script:loadedSnapshotItems.Count -eq 0) {
        Show-MklinkError -Message 'Please load a snapshot first.'
        return
    }

    $res = Show-RedirectDialog
    if ($res) {
        $find = $res.Find
        $replace = $res.Replace
        
        if ([string]::IsNullOrEmpty($find)) { return }

        $changedCount = 0
        foreach ($item in $script:loadedSnapshotItems) {
            if ($item.Target -like "*$find*") {
                $item.Target = $item.Target -replace [regex]::Escape($find), $replace
                $changedCount++
            }
        }
        
        Load-SnapshotGridData
        $script:lblStatus.Text = "Redirected $changedCount targets ($find -> $replace)."
    }
})

$script:btnApplyChecked.Add_Click({
    $checkedRows = @()
    foreach ($row in $script:dgvSnapshot.Rows) {
        if ($row.Cells['Check'].Value) {
            $checkedRows += $row
        }
    }

    if ($checkedRows.Count -eq 0) {
        Show-MklinkError -Message 'No junctions selected. Please check the items you want to apply.'
        return
    }

    $message = "Apply $($checkedRows.Count) selected junctions?`n`nNote: If the Link folder already exists as a normal directory, it will be automatically backed up by adding '_backup' to its name."
    if (-not (Confirm-MklinkAction -Message $message)) { return }

    $successCount = 0
    $failCount = 0
    
    $overwriteAllBackups = $false
    $skipAllConflicts = $false

    foreach ($row in $checkedRows) {
        $link = [string]$row.Cells['Link'].Value
        $target = [string]$row.Cells['Target'].Value
        
        if (-not (Test-Path -LiteralPath $target)) {
            $row.Cells['Status'].Value = 'TARGET MISSING'
            $failCount++
            continue
        }

        $applied = $false
        $tryApply = $true
        $forceBackup = $false
        
        while ($tryApply) {
            try {
                $result = Restore-MklinkJunction -LinkPath $link -TargetPath $target -OverwriteBackup ($overwriteAllBackups -or $forceBackup)
                if ($result.Status -eq 'Success' -or $result.Status -eq 'AlreadyExists') {
                    $row.Cells['Status'].Value = 'APPLIED'
                    $row.Cells['Check'].Value = $false
                    $successCount++
                    $applied = $true
                    $tryApply = $false
                }
                elseif ($result.Status -eq 'BackupConflict') {
                    if ($skipAllConflicts) {
                        $row.Cells['Status'].Value = 'CONFLICT'
                        $failCount++
                        $tryApply = $false
                        break
                    }
                    if ($overwriteAllBackups) {
                        $forceBackup = $true
                        continue
                    }

                    $conflictMsg = "A backup folder already exists at:`n$($result.BackupPath)`n`nDo you want to overwrite it?`n(Yes = Overwrite, No = Skip, Cancel = Stop whole process)"
                    $choice = [System.Windows.Forms.MessageBox]::Show(
                        $script:form,
                        $conflictMsg,
                        'Backup Conflict',
                        [System.Windows.Forms.MessageBoxButtons]::YesNoCancel,
                        [System.Windows.Forms.MessageBoxIcon]::Warning
                    )
                    
                    if ($choice -eq [System.Windows.Forms.DialogResult]::Yes) {
                        $forceBackup = $true
                    }
                    elseif ($choice -eq [System.Windows.Forms.DialogResult]::No) {
                        $row.Cells['Status'].Value = 'CONFLICT'
                        $failCount++
                        $tryApply = $false
                    }
                    else {
                        $row.Cells['Status'].Value = 'CONFLICT'
                        $failCount++
                        $tryApply = $false
                        $script:lblStatus.Text = "Process aborted. Applied $successCount, failed/skipped $failCount."
                        Load-SnapshotGridData
                        return
                    }
                }
            }
            catch {
                $row.Cells['Status'].Value = 'ERROR'
                $failCount++
                $tryApply = $false
                Write-MklinkLog "Error restoring junction ${link} -> ${target}: $($_.Exception.Message)"
            }
        }
    }

    $script:lblStatus.Text = "Restore complete: $successCount applied, $failCount failed/skipped."
    Load-SnapshotGridData
})

$script:btnCaptureLive.Add_Click({
    try {
        $junctions = Get-UserJunctions
        $script:loadedSnapshotItems.Clear()
        foreach ($j in $junctions) {
            $script:loadedSnapshotItems.Add([PSCustomObject]@{
                Name     = $j.Name
                Link     = $j.Link
                Target   = $j.Target
                Category = $j.Category
                OriginalLink = $j.Link -ireplace ([regex]::Escape($env:USERPROFILE), '%USERPROFILE%')
                OriginalTarget = $j.Target -ireplace ([regex]::Escape($env:USERPROFILE), '%USERPROFILE%')
            })
        }
        $script:btnToggleAll.Text = 'Uncheck All'
        Load-SnapshotGridData
        $script:lblStatus.Text = "Captured $($junctions.Count) live junctions into snapshot list."
    }
    catch {
        Show-MklinkError -Message "Failed to capture live junctions: $($_.Exception.Message)"
    }
})

# Initialize button positions and labels
Set-TitleButtonPositions
if ($script:lblHelp) {
    $rightLimit = $script:pnlTitle.ClientSize.Width - $(Scale 20)
    $script:lblHelp.Location = [System.Drawing.Point]::new($rightLimit - $script:lblHelp.Width, $(Scale 62))
}
Update-PendingSourceStatus

# ── TabControl Layout Assembly ──
$script:tabControl = [System.Windows.Forms.TabControl]::new()
$script:tabControl.Dock = 'Fill'
$script:tabControl.Font = [System.Drawing.Font]::new($script:fontFamily, 9.5, [System.Drawing.FontStyle]::Bold)

$script:tabLive = [System.Windows.Forms.TabPage]::new('Live Junctions')
$script:tabLive.BackColor = $script:clrBg
$script:tabLive.ForeColor = $script:clrText
$script:tabLive.Controls.Add($script:dgv)

$script:tabSnapshot = [System.Windows.Forms.TabPage]::new('Snapshot Junctions')
$script:tabSnapshot.BackColor = $script:clrBg
$script:tabSnapshot.ForeColor = $script:clrText
$script:tabSnapshot.Controls.Add($script:dgvSnapshot)

$script:tabControl.TabPages.Add($script:tabLive)
$script:tabControl.TabPages.Add($script:tabSnapshot)

$script:tabControl.Add_SelectedIndexChanged({
    Set-TitleButtonPositions
    if ($script:tabControl.SelectedIndex -eq 0) {
        $script:lblSubtitle.Text = 'Active Junctions & Symbolic Links'
        Load-JunctionData
    } else {
        $script:lblSubtitle.Text = 'Manage and Restore Junction Snapshots'
        Update-SnapshotStatusText
    }
})

# WinForms Dock order: Fill must be added FIRST to the form,
# then Bottom, then Top (last-added Dock=Top renders on top)
$script:form.Controls.Add($script:tabControl)
$script:form.Controls.Add($script:pnlStatus)
$script:form.Controls.Add($script:pnlTitle)

# ── Initial Load on Shown ──
$script:form.Add_Shown({ Load-JunctionData })

# ── Run ──
[void]$script:form.ShowDialog()

# Cleanup
$script:form.Dispose()
