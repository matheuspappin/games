@echo off
docker compose version > "C:\gemini cli\games\_prints\dockerver.log" 2>&1
docker ps >> "C:\gemini cli\games\_prints\dockerver.log" 2>&1
