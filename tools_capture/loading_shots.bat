@echo off
cd /d "C:\gemini cli\games"
powershell -NoProfile -Command "Get-CimInstance Win32_Process | Where-Object { $_.Name -like 'Godot*' -and $_.CommandLine -like '*loading_shots*' } | ForEach-Object { Stop-Process -Id $_.ProcessId -Force }"
timeout /t 2 /nobreak > nul
"C:\Users\lala\Desktop\Godot_v4.7.2-stable_win64.exe" --path "C:\gemini cli\games" --resolution 1920x1080 res://tools_capture/loading_shots.tscn > "C:\gemini cli\games\_prints\loading_shots.log" 2>&1
echo FIM >> "C:\gemini cli\games\_prints\loading_shots.log"
