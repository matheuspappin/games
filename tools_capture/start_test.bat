@echo off
start "srv" /b cmd /c "C:\gemini cli\games\tools_capture\run_server_local.bat"
start "web" /b cmd /c "C:\gemini cli\games\tools_capture\serve_web.bat"
