@echo off
powershell -NoProfile -Command "Get-Process | Where-Object { $_.ProcessName -like 'Godot*' -and $_.MainWindowTitle -like '*Godot Engine*' } | ForEach-Object { $_.CloseMainWindow() | Out-Null }; Start-Sleep 8; Get-CimInstance Win32_Process | Where-Object { $_.Name -like 'Godot*' -and $_.CommandLine -like '*--editor*' } | ForEach-Object { Stop-Process -Id $_.ProcessId -Force }"
call "C:\gemini cli\games\tools_capture\import.bat"
