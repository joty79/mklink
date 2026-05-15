# Changelog

## 2026-05-11

- Added InstallerCore onboarding with generated `Install.ps1`, `app-metadata.json`, and repo-local `.assets\icons\mklink.ico`.
- Added `InstallerCore\profiles\mklink.json` as the source-of-truth installer profile for install/update/uninstall and context-menu registry entries.
- Regenerated `Install.ps1` with InstallerCore self-elevated registry repair, so right-click `Run with PowerShell 7` can prompt for UAC only when protected legacy context-menu cleanup needs admin rights.
- Fixed context-menu cascade registration by explicitly writing empty `SubCommands` values on `mklink` parent keys and expanding legacy cleanup for old HKCU/HKCR entries.
- Updated troubleshooting docs to explain the automatic UAC repair prompt for protected HKCR or machine-level context-menu cleanup.
- Added `MklinkCore.ps1` as the shared implementation for pending source, create junction, revert junction, change destination, and junction scanning.
- Refactored Explorer scripts to use the shared core instead of duplicating move/junction logic.
- Expanded `MklinkManager.ps1` with `Create`, `Revert`, `Change`, and `Clear Source` actions plus row context-menu actions.
- Reworked `mklink.reg` into a current-user `mklink` submenu for folder and folder-background right-click workflows.
- Added VBS/script launchers for Manager, clear pending source, and revert junction.
- Added `README.md` usage and structure documentation.
