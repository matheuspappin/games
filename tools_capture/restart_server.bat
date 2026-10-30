@echo off
powershell -NoProfile -Command "Get-CimInstance Win32_Process | Where-Object { $_.CommandLine -like '*-- --server --port=7777*' -and $_.Name -like 'Godot*' } | ForEach-Object { Stop-Process -Id $_.ProcessId -Force }"
timeout /t 2 /nobreak > nul
start "srv" /b cmd /c "C:\gemini cli\games\tools_capture\run_server_local.bat"
