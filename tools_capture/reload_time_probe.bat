@echo off
powershell -NoProfile -Command "Get-CimInstance Win32_Process | Where-Object { $_.Name -like 'Godot*' -and $_.CommandLine -like '*_probe*' } | ForEach-Object { Stop-Process -Id $_.ProcessId -Force }"
cd /d "C:\gemini cli\games"
"C:\Users\lala\Desktop\Godot_v4.7.2-stable_win64.exe" --path "C:\gemini cli\games" --resolution 1280x720 res://tools_capture/reload_time_probe.tscn > "C:\gemini cli\games\_prints\reload_time_probe.log" 2>&1
