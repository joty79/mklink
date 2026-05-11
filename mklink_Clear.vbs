' Silent wrapper for mklinkClearSource.ps1
' Location: D:\Users\joty79\scripts\mklink

Set objShell = CreateObject("WScript.Shell")

command = "pwsh.exe -WindowStyle Hidden -ExecutionPolicy Bypass -File ""D:\Users\joty79\scripts\mklink\mklinkClearSource.ps1"""
objShell.Run command, 0, False
