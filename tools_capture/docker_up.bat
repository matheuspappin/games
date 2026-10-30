@echo off
cd /d "C:\gemini cli\games\server"
docker compose -f docker-compose.yml -f docker-compose.local.yml up -d --build nuke-dedicated-server > "C:\gemini cli\games\_prints\docker_up.log" 2>&1
echo FIM %ERRORLEVEL% >> "C:\gemini cli\games\_prints\docker_up.log"
