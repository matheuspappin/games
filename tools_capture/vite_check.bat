@echo off
cd /d "C:\gemini cli\games\web"
call npx vite build --outDir "C:\gemini cli\games\_prints\webbuild" --emptyOutDir > "C:\gemini cli\games\_prints\vite.log" 2>&1
echo FIM %ERRORLEVEL% >> "C:\gemini cli\games\_prints\vite.log"
