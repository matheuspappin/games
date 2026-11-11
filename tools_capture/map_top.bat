@echo off
powershell -NoProfile -Command "Get-CimInstance Win32_Process | Where-Object { $_.Name -like 'Godot*' -and ($_.CommandLine -like '*_probe*' -or $_.CommandLine -like '*map_*') } | ForEach-Object { Stop-Process -Id $_.ProcessId -Force }"
cd /d "C:\gemini cli\games"
"C:\Users\lala\Desktop\Godot_v4.7.2-stable_win64.exe" --path "C:\gemini cli\games" --resolution 1000x1000 res://tools_capture/map_top.tscn -- --map=res://scenes/_world/map_nuketown_1v1.tscn --name=classic > "C:\gemini cli\games\_prints\map_top.log" 2>&1
