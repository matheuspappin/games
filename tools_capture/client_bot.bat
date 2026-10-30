@echo off
cd /d "C:\gemini cli\games"
"C:\Users\lala\Desktop\Godot_v4.7.2-stable_win64.exe" --headless --path "C:\gemini cli\games" -- --client --server-ip=127.0.0.1 --port=7777 > "C:\gemini cli\games\_prints\client_bot.log" 2>&1
