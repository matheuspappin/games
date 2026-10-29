@echo off
cd /d "C:\gemini cli\games\web\public\game"
python -m http.server 8060 --bind 127.0.0.1 > "C:\gemini cli\games\_prints\http.log" 2>&1
