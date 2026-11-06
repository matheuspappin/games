@echo off
cd /d "C:\gemini cli\games"
"C:\Users\lala\Desktop\Godot_v4.7.2-stable_win64.exe" --headless --path "C:\gemini cli\games" res://tools_capture/net_probe.tscn -- --client --server-ip=127.0.0.1 --port=7778 --role=target > "C:\gemini cli\games\_prints\net_target.log" 2>&1
