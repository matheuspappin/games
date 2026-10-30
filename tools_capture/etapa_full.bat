@echo off
call "C:\gemini cli\games\tools_capture\import.bat"
call "C:\gemini cli\games\tools_capture\export_web.bat"
echo etapa3b> "C:\gemini cli\games\_prints\bo3_tag.txt"
call "C:\gemini cli\games\tools_capture\bo3_shots.bat"
