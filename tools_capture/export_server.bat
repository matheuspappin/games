@echo off
cd /d "C:\gemini cli\games"
"C:\Users\lala\Desktop\Godot_v4.7.2-stable_win64.exe" --headless --path "C:\gemini cli\games" --export-release "Linux Dedicated Server" "C:\gemini cli\games\server\bin\server.x86_64" > "C:\gemini cli\games\_prints\export_server.log" 2>&1
echo FIM %ERRORLEVEL% >> "C:\gemini cli\games\_prints\export_server.log"
