# Project Rules - mklink

## 🔵 Repository Information
- **Name:** mklink
- **Primary Branch:** master (Transitioning from main)

## 🔵 History & Guardrails
- **2026-05-10:** Transitioned default branch from `main` to `master`.
  - Local branch renamed/confirmed as `master`.
  - Remote synchronization required (Default branch update in UI + delete main).

- **2026-05-11:** Introduced shared `MklinkCore.ps1` for all junction operations.
  - Problem: Explorer scripts and Manager needed create/revert/change behavior without duplicated move logic.
  - Root cause: Initial implementation was one-way and context-menu focused, while Manager only displayed junctions.
  - Guardrail/rule: Keep destructive junction operations in `MklinkCore.ps1`; wrappers and GUI must call the shared functions.
  - Files affected: `MklinkCore.ps1`, `mklinkSource.ps1`, `mklinkTarget.ps1`, `mklinkRevert.ps1`, `mklinkClearSource.ps1`, `MklinkManager.ps1`, `mklink.reg`.
  - Validation/tests run: PowerShell parser validation for edited `.ps1` files.

- **2026-05-11:** Onboarded mklink to InstallerCore.
  - Problem: The repo needed a classic generated installer instead of manual `.reg` import as the main setup path.
  - Root cause: Context-menu registration, runtime asset deployment, uninstall entry, and updates were not modeled in an InstallerCore profile.
  - Guardrail/rule: Treat `D:\Users\joty79\scripts\InstallerCore\profiles\mklink.json` as the source of truth for installer registry/files; regenerate `Install.ps1` from InstallerCore instead of editing it by hand.
  - Files affected: `Install.ps1`, `app-metadata.json`, `.assets\icons\mklink.ico`, `README.md`, `CHANGELOG.md`, InstallerCore `profiles\mklink.json`.
  - Validation/tests run: InstallerCore generator, generated installer parser validation.
