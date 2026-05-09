' Elevated wrapper for mklinkTarget.ps1 using Windows Terminal
' Location: D:\Users\joty79\scripts\mklink
' Runs with admin rights to create junction

Set objShell = CreateObject("Shell.Application")

' Get the folder path from arguments
If WScript.Arguments.Count > 0 Then
    folderPath = WScript.Arguments(0)
    
    ' Build the argument string for wt
    args = "new-tab pwsh -ExecutionPolicy Bypass -File ""D:\Users\joty79\scripts\mklink\mklinkTarget.ps1"" """ & folderPath & """"
    
    ' Run wt.exe as admin (runas)
    objShell.ShellExecute "wt.exe", args, "", "runas", 1
End If
