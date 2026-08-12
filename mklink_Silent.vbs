' Silent wrapper for mklinkSource.ps1
' Location: D:\Users\joty79\scripts\mklink
' Stores the folder path in registry without showing a window

Set objShell = CreateObject("WScript.Shell")

' Get the folder path from arguments
If WScript.Arguments.Count > 0 Then
    folderPath = WScript.Arguments(0)
    mode = "MoveSource"
    If WScript.Arguments.Count > 1 Then
        mode = WScript.Arguments(1)
    End If
    
    command = "pwsh.exe -WindowStyle Hidden -ExecutionPolicy Bypass -File ""D:\Users\joty79\scripts\mklink\mklinkSource.ps1"" -FolderPath """ & folderPath & """ -Mode """ & mode & """"
    
    ' Run silently (0 = hidden, False = don't wait)
    objShell.Run command, 0, False
End If
