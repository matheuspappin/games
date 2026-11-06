@echo off
cd /d "C:\gemini cli\games"
"C:\Users\lala\Desktop\Godot_v4.7.2-stable_win64.exe" --headless --path "C:\gemini cli\games" res://tools_capture/net_probe.tscn -- --client --server-ip=localhost --port=8090 --role=shooter > "C:\gemini cli\games\_prints\net_shooter.log" 2>&1
cd /d "C:\gemini cli\games\server"
docker compose logs --tail 60 nuke-dedicated-server > "C:\gemini cli\games\_prints\compose_logs.log" 2>&1
dir /b results >> "C:\gemini cli\games\_prints\compose_logs.log" 2>&1
echo FIM > "C:\gemini cli\games\_prints\net_done.log"
