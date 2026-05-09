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
# Junction Scanner
# ─────────────────────────────────────────────────────────────────
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
        if (-not (Test-Path $root)) { continue }
        
        $items = Get-ChildItem -Path $root -Recurse -Depth 4 -Force `
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
            
            # Categorize
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

# ─────────────────────────────────────────────────────────────────
# Build Form
# ─────────────────────────────────────────────────────────────────


$script:form = [System.Windows.Forms.Form]@{
    Text            = 'mklink Manager'
    Size            = [System.Drawing.Size]::new(1050, 680)
    MinimumSize     = [System.Drawing.Size]::new(800, 500)
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
$script:pnlTitle.Height    = $(Scale 70)
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

# ── Refresh Button (in title bar) ──
$script:btnRefresh = [System.Windows.Forms.Button]::new()
$script:btnRefresh.Text      = 'Refresh'
$script:btnRefresh.Font      = $script:fontButton
$script:btnRefresh.Size      = [System.Drawing.Size]::new($(Scale 100), $(Scale 34))
$script:btnRefresh.FlatStyle = 'Flat'
$script:btnRefresh.BackColor = $script:clrAccent
$script:btnRefresh.ForeColor = [System.Drawing.Color]::White
$script:btnRefresh.Cursor    = [System.Windows.Forms.Cursors]::Hand
$script:btnRefresh.Anchor    = 'Top, Right'
$script:btnRefresh.FlatAppearance.BorderSize = 0
$script:btnRefresh.Location = [System.Drawing.Point]::new($script:pnlTitle.ClientSize.Width - ($(Scale 120)), $(Scale 18))
$script:pnlTitle.Controls.Add($script:btnRefresh)

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

# ── DataGridView ──
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

# ── Columns ──
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


# ── Context Menu ──
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

$ctxMenu.Items.AddRange(@($ctxOpenLink, $ctxOpenTarget, $ctxCopyLink, $ctxCopyTarget))
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

# ── Load Data Function ──
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
}

# ── Refresh button position update on resize ──
$script:pnlTitle.Add_Resize({
    $script:btnRefresh.Location = [System.Drawing.Point]::new($script:pnlTitle.ClientSize.Width - ($(Scale 120)), $(Scale 18))
})

# ── Refresh click ──
$script:btnRefresh.Add_Click({ Load-JunctionData })

# ── Assemble Layout ──
# WinForms Dock order: Fill must be added FIRST to the form,
# then Bottom, then Top (last-added Dock=Top renders on top)
$script:form.Controls.Add($script:dgv)
$script:form.Controls.Add($script:pnlStatus)
$script:form.Controls.Add($script:pnlTitle)

# ── Initial Load on Shown ──
$script:form.Add_Shown({ Load-JunctionData })

# ── Run ──
[void]$script:form.ShowDialog()

# Cleanup
$script:form.Dispose()
