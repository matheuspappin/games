@echo off
call "C:\gemini cli\games\tools_capture\export_all.bat"
call "C:\gemini cli\games\tools_capture\restart_server.bat"
start "web" /b cmd /c "C:\gemini cli\games\tools_capture\serve_web.bat"
echo TUDO_PRONTO > "C:\gemini cli\games\_prints\build_geral.log"
