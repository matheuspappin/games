@echo off
cd /d "C:\gemini cli\games"
"C:\Users\lala\Desktop\Godot_v4.7.2-stable_win64.exe" --headless --path "C:\gemini cli\games" -- --server --port=7777 > "C:\gemini cli\games\_prints\server_local.log" 2>&1
