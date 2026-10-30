@echo off
powershell -NoProfile -Command "Get-CimInstance Win32_Process | Where-Object { $_.CommandLine -like '*--quit-after 400*' -and $_.Name -like 'Godot*' } | ForEach-Object { Stop-Process -Id $_.ProcessId -Force }"
