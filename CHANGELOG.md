# Changelog

## 2026-05-11

- Added `MklinkCore.ps1` as the shared implementation for pending source, create junction, revert junction, change destination, and junction scanning.
- Refactored Explorer scripts to use the shared core instead of duplicating move/junction logic.
- Expanded `MklinkManager.ps1` with `Create`, `Revert`, `Change`, and `Clear Source` actions plus row context-menu actions.
- Reworked `mklink.reg` into a current-user `mklink` submenu for folder and folder-background right-click workflows.
- Added VBS/script launchers for Manager, clear pending source, and revert junction.
- Added `README.md` usage and structure documentation.
