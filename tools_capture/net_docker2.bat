@echo off
cd /d "C:\gemini cli\games"
start "" /b cmd /c ""C:\Users\lala\Desktop\Godot_v4.7.2-stable_win64.exe" --headless --path "C:\gemini cli\games" res://tools_capture/net_probe.tscn -- --client --server-ip=localhost --port=8090 --role=target > "C:\gemini cli\games\_prints\net_target.log" 2>&1"
timeout /t 20 /nobreak > nul
"C:\Users\lala\Desktop\Godot_v4.7.2-stable_win64.exe" --headless --path "C:\gemini cli\games" res://tools_capture/net_probe.tscn -- --client --server-ip=localhost --port=8090 --role=shooter > "C:\gemini cli\games\_prints\net_shooter.log" 2>&1
timeout /t 5 /nobreak > nul
powershell -NoProfile -Command "Get-CimInstance Win32_Process | Where-Object { $_.Name -like 'Godot*' -and $_.CommandLine -like '*net_probe*' } | ForEach-Object { Stop-Process -Id $_.ProcessId -Force }"
cd /d "C:\gemini cli\games\server"
docker compose logs --tail 80 nuke-dedicated-server > "C:\gemini cli\games\_prints\compose_logs.log" 2>&1
echo FIM > "C:\gemini cli\games\_prints\net_done.log"
