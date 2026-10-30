@echo off
cd /d "C:\gemini cli\games"
"C:\Users\lala\Desktop\Godot_v4.7.2-stable_win64.exe" --path "C:\gemini cli\games" --resolution 1280x720 -- --client --server-ip=127.0.0.1 --port=7777 --qa-shot="C:/gemini cli/games/_prints/mp_qa.png" > "C:\gemini cli\games\_prints\mp_qa.log" 2>&1
