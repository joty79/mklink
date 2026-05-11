' Visible GUI wrapper for MklinkManager.ps1
' Location: D:\Users\joty79\scripts\mklink

Set objShell = CreateObject("WScript.Shell")

command = "pwsh.exe -WindowStyle Hidden -ExecutionPolicy Bypass -File ""D:\Users\joty79\scripts\mklink\MklinkManager.ps1"""
objShell.Run command, 0, False
