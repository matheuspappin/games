@echo off
cd /d "C:\gemini cli\games"
set G="C:\Users\lala\Desktop\Godot_v4.7.2-stable_win64.exe"
start "srv" /b cmd /c "%G% --headless --quit-after 12000 --path "C:\gemini cli\games" -- --server --port=7777 > "C:\gemini cli\games\_prints\mp_server.log" 2>&1"
timeout /t 25 /nobreak > nul
echo INICIO %time% > "C:\gemini cli\games\_prints\mp_time.log"
%G% --headless --quit-after 20000 --path "C:\gemini cli\games" -- --client --server-ip=127.0.0.1 --port=7777 > "C:\gemini cli\games\_prints\mp_client.log" 2>&1
echo FIM %time% >> "C:\gemini cli\games\_prints\mp_time.log"
