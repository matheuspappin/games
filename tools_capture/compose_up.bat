@echo off
set T=0
:w
docker info > nul 2>&1
if not errorlevel 1 goto up
set /a T+=1
if %T% GEQ 60 goto fail
timeout /t 5 /nobreak > nul
goto w
:up
cd /d "C:\gemini cli\games\server"
docker compose -f docker-compose.yml -f docker-compose.local.yml up -d --build > "C:\gemini cli\games\_prints\compose_up.log" 2>&1
echo FIM %ERRORLEVEL% >> "C:\gemini cli\games\_prints\compose_up.log"
docker compose ps >> "C:\gemini cli\games\_prints\compose_up.log" 2>&1
goto end
:fail
echo DOCKER_NAO_SUBIU > "C:\gemini cli\games\_prints\compose_up.log"
:end
