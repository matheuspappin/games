@echo off
cd /d "C:\gemini cli\games"
echo INICIO %time% > "C:\gemini cli\games\_prints\import.log"
"C:\Users\lala\Desktop\Godot_v4.7.2-stable_win64.exe" --headless --path "C:\gemini cli\games" --import >> "C:\gemini cli\games\_prints\import.log" 2>&1
echo FIM %time% >> "C:\gemini cli\games\_prints\import.log"
