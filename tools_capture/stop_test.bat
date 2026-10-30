@echo off
powershell -NoProfile -Command "Get-CimInstance Win32_Process | Where-Object { ($_.CommandLine -like '*-- --server*' -and $_.Name -like 'Godot*') -or ($_.CommandLine -like '*http.server 8060*') } | ForEach-Object { Stop-Process -Id $_.ProcessId -Force }"
