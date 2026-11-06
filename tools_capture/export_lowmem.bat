@echo off
taskkill /IM "Docker Desktop.exe" /F > nul 2>&1
wsl --shutdown > nul 2>&1
timeout /t 5 /nobreak > nul
call "C:\gemini cli\games\tools_capture\export_server.bat"
call "C:\gemini cli\games\tools_capture\export_web.bat"
echo EXPORT_OK > "C:\gemini cli\games\_prints\export_lowmem.log"
