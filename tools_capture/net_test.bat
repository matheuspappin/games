@echo off
cd /d "C:\gemini cli\games"
powershell -NoProfile -Command "Get-CimInstance Win32_Process | Where-Object { $_.Name -like 'Godot*' -and ($_.CommandLine -like '*net_probe*' -or $_.CommandLine -like '*--port=7778*') } | ForEach-Object { Stop-Process -Id $_.ProcessId -Force }"
timeout /t 3 /nobreak > nul
start "" /b cmd /c "C:\gemini cli\games\tools_capture\net_srv.bat"
timeout /t 25 /nobreak > nul
start "" /b cmd /c "C:\gemini cli\games\tools_capture\net_tgt.bat"
timeout /t 15 /nobreak > nul
"C:\Users\lala\Desktop\Godot_v4.7.2-stable_win64.exe" --headless --path "C:\gemini cli\games" res://tools_capture/net_probe.tscn -- --client --server-ip=127.0.0.1 --port=7778 --role=shooter > "C:\gemini cli\games\_prints\net_shooter.log" 2>&1
timeout /t 5 /nobreak > nul
powershell -NoProfile -Command "Get-CimInstance Win32_Process | Where-Object { $_.Name -like 'Godot*' -and ($_.CommandLine -like '*net_probe*' -or $_.CommandLine -like '*--port=7778*') } | ForEach-Object { Stop-Process -Id $_.ProcessId -Force }"
echo FIM > "C:\gemini cli\games\_prints\net_done.log"
