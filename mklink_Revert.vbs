' Elevated wrapper for mklinkRevert.ps1 using Windows Terminal
' Location: D:\Users\joty79\scripts\mklink

Set objShell = CreateObject("Shell.Application")

If WScript.Arguments.Count > 0 Then
    folderPath = WScript.Arguments(0)
    args = "new-tab pwsh -ExecutionPolicy Bypass -File ""D:\Users\joty79\scripts\mklink\mklinkRevert.ps1"" """ & folderPath & """"
    objShell.ShellExecute "wt.exe", args, "", "runas", 1
End If
