@echo off
docker builder prune -af > "C:\gemini cli\games\_prints\docker_prune.log" 2>&1
docker image prune -f >> "C:\gemini cli\games\_prints\docker_prune.log" 2>&1
echo FIM >> "C:\gemini cli\games\_prints\docker_prune.log"
