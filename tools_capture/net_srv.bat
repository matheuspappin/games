@echo off
cd /d "C:\gemini cli\games"
set MATCH_SECRET=segredo-de-teste
set "RESULTS_DIR=C:\gemini cli\games\_prints\results"
"C:\Users\lala\Desktop\Godot_v4.7.2-stable_win64.exe" --headless --path "C:\gemini cli\games" -- --server --port=7778 --map=nuketown_classic --shot-log --target-kills=1 > "C:\gemini cli\games\_prints\net_server.log" 2>&1
