@echo off
cd /d "C:\gemini cli\games"
"C:\Users\lala\Desktop\Godot_v4.7.2-stable_win64.exe" --headless --path "C:\gemini cli\games" --export-release "Web" "C:\gemini cli\games\web\public\game\index.html" > "C:\gemini cli\games\_prints\export_web.log" 2>&1
echo FIM %ERRORLEVEL% >> "C:\gemini cli\games\_prints\export_web.log"
