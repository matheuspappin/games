@echo off
docker info > "C:\gemini cli\games\_prints\dinfo.log" 2>&1
tasklist | findstr /i "docker vmmem wsl" >> "C:\gemini cli\games\_prints\dinfo.log" 2>&1
wsl -l -v >> "C:\gemini cli\games\_prints\dinfo.log" 2>&1
