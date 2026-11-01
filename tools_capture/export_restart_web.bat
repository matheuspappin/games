@echo off
call "C:\gemini cli\games\tools_capture\export_web.bat"
call "C:\gemini cli\games\tools_capture\restart_server.bat"
start "web" /b cmd /c "C:\gemini cli\games\tools_capture\serve_web.bat"
