Option Explicit

Dim shell, fso, scriptDir, mainPath, cmd
Set shell = CreateObject("WScript.Shell")
Set fso = CreateObject("Scripting.FileSystemObject")

scriptDir = fso.GetParentFolderName(WScript.ScriptFullName)
mainPath = scriptDir & "\main.ps1"

cmd = "powershell.exe -NoProfile -ExecutionPolicy Bypass -File """ & mainPath & """"
shell.Run cmd, 0, False
