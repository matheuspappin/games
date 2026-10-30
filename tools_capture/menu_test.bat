@echo off
cd /d "C:\gemini cli\games"
"C:\Users\lala\Desktop\Godot_v4.7.2-stable_win64.exe" --path "C:\gemini cli\games" --quit-after 400 > "C:\gemini cli\games\_prints\menu_test.log" 2>&1
echo FIM %ERRORLEVEL% >> "C:\gemini cli\games\_prints\menu_test.log"
