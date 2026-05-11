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
