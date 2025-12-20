Set WshShell = CreateObject("WScript.Shell")
strPath = CreateObject("Scripting.FileSystemObject").GetParentFolderName(WScript.ScriptFullName) & "\immich-tray.ps1"
cmd = "powershell.exe -WindowStyle Hidden -ExecutionPolicy Bypass -File " & chr(34) & strPath & chr(34)
WshShell.Run cmd, 0
Set WshShell = Nothing
