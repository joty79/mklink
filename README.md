<p align="center">
  <img src="https://img.shields.io/badge/Platform-Windows-0078D4?style=for-the-badge&logo=windows&logoColor=white" alt="Platform">
  <img src="https://img.shields.io/badge/Language-PowerShell-5391FE?style=for-the-badge&logo=powershell&logoColor=white" alt="Language">
</p>

<h1 align="center">mklink Manager</h1>

<p align="center">
  <b>Windows context-menu workflow για μεταφορά folders και δημιουργία junctions.</b><br>
  <sub>διάλεξε source -> διάλεξε destination -> διαχειρίσου junctions από GUI</sub>
</p>

## What's Inside

| # | Tool | Description |
|:-:|------|-------------|
| 1 | **[Context Menu](#context-menu)** | Explorer right-click entries για source, create, revert και Manager |
| 2 | **[Mklink Manager](#mklink-manager)** | WinForms GUI για προβολή, revert και αλλαγή destination |
| 3 | **[Mklink Core](#mklink-core)** | Κοινή PowerShell λογική που χρησιμοποιούν scripts και Manager |

## Context Menu

Το `mklink.reg` δημιουργεί current-user submenu κάτω από `HKCU\Software\Classes`.

```text
Right-click σε folder:
mklink
  Set as source
  Revert junction
  Open Manager
  Clear pending source

Right-click σε folder background:
mklink
  Create junction here
  Open Manager
  Clear pending source
```

### Flow

```text
Folder A
  -> Set as source

Destination folder background
  -> Create junction here

Result
  Folder A moves to Destination\Folder A
  Original Folder A path becomes a junction
```

## Mklink Manager

`MklinkManager.ps1` σκανάρει junctions κάτω από το user profile και δείχνει status, category, junction path και target path.

| Action | Behavior |
|--------|----------|
| `Create` | Χρησιμοποιεί το pending source και ζητά destination folder |
| `Revert` | Αφαιρεί το junction και μεταφέρει το target folder πίσω στο original path |
| `Change` | Μεταφέρει το current target σε νέο destination και ξαναδημιουργεί το junction |
| `Clear Source` | Καθαρίζει το saved pending source |
| Row context menu | Open/copy paths, change destination, revert junction |

## Mklink Core

`MklinkCore.ps1` είναι το shared API για όλα τα scripts.

| Function | Purpose |
|----------|---------|
| `Set-MklinkPendingSource` | Αποθηκεύει source folder στο registry |
| `Get-MklinkPendingSource` | Διαβάζει το pending source |
| `Clear-MklinkPendingSource` | Καθαρίζει το pending source |
| `New-MklinkJunctionMove` | Μεταφέρει folder και δημιουργεί junction |
| `Revert-MklinkJunction` | Επαναφέρει junction σε κανονικό folder |
| `Move-MklinkJunctionTarget` | Αλλάζει destination ενός junction |
| `Get-UserJunctions` | Σκανάρει user profile για junctions |

## Installation

Preferred setup είναι το generated InstallerCore installer:

```powershell
pwsh -ExecutionPolicy Bypass -File "D:\Users\joty79\scripts\mklink\Install.ps1"
```

Το installer εγκαθιστά τα runtime files κάτω από `%LOCALAPPDATA%\mklink`, γράφει το current-user context menu και κρατά uninstall entry.

Αν αναβαθμίζεις από παλιό context menu και μείνουν extra entries όπως `mklink Target (Junction)`, τρέξε το ίδιο installer elevated/as Administrator. Αυτό σημαίνει ότι υπάρχει παλιό `HKCR` ή machine-level leftover που δεν καθαρίζεται αξιόπιστα από non-admin launch.

Το `mklink.reg` μένει σαν manual/reference artifact αν θέλεις να αλλάξεις μόνο το live Explorer context menu από το working copy.

```powershell
reg import "D:\Users\joty79\scripts\mklink\mklink.reg"
```

Για άνοιγμα του Manager χωρίς context menu:

```powershell
pwsh -ExecutionPolicy Bypass -File "D:\Users\joty79\scripts\mklink\MklinkManager.ps1"
```

## Requirements

| Requirement | Details |
|-------------|---------|
| OS | Windows 10/11 |
| Runtime | PowerShell 7 |
| Shell | Windows Terminal για elevated create/revert wrappers |
| Explorer integration | `.reg` import από τον χρήστη |

## Project Structure

```text
mklink/
├── Install.ps1           # Generated InstallerCore installer
├── app-metadata.json     # App/version metadata for installer
├── .assets/
│   └── icons/
│       └── mklink.ico    # Context-menu icon
├── MklinkCore.ps1        # Shared junction logic
├── MklinkManager.ps1     # WinForms GUI manager
├── MklinkManager.vbs     # Hidden console launcher for GUI
├── mklinkSource.ps1      # Stores pending source
├── mklinkTarget.ps1      # Creates junction at destination
├── mklinkRevert.ps1      # Reverts selected junction
├── mklinkClearSource.ps1 # Clears pending source
├── mklink_Silent.vbs     # Explorer wrapper for source
├── mklink_Target.vbs     # Elevated Explorer wrapper for create
├── mklink_Revert.vbs     # Elevated Explorer wrapper for revert
├── mklink_Clear.vbs      # Explorer wrapper for clear
├── mklink.reg            # Context-menu registry artifact
├── PROJECT_RULES.md      # Project memory
└── README.md             # Documentation
```

## Technical Notes

<details>
<summary><b>Γιατί υπάρχει MklinkCore.ps1;</b></summary>

Η create/revert/change λογική πρέπει να είναι κοινή ανάμεσα στα Explorer scripts και στο Manager. Έτσι αποφεύγεται duplicated behavior και μειώνεται το ρίσκο να κάνει κάθε entry διαφορετικό move ή cleanup.

</details>

<details>
<summary><b>Γιατί το .reg γράφει σε HKCU;</b></summary>

Το current-user scope είναι πιο ασφαλές για Explorer context-menu entries και αποφεύγει global HKCR writes. Το artifact καθαρίζει και παλιά HKCR entries, αλλά δεν εφαρμόζεται αυτόματα από τα scripts.

</details>

<details>
<summary><b>Τι προστασίες υπάρχουν στα destructive actions;</b></summary>

Το core επιβεβαιώνει ότι το selected path είναι folder junction πριν κάνει revert ή change destination. Το Manager δείχνει confirmation dialog με source και target πριν εκτελέσει move operations.

</details>

---

<p align="center">
  <sub>Built with PowerShell · Explorer context menu · Junction manager</sub>
</p>
