@echo off
cd /d "C:\gemini cli\games\server"
docker compose logs --tail 40 > "C:\gemini cli\games\_prints\compose_logs.log" 2>&1
curl -s -o nul -w "index %{http_code} %{size_download}\n" http://localhost:8090/index.html >> "C:\gemini cli\games\_prints\compose_logs.log" 2>&1
curl -s -o nul -H "Accept-Encoding: zstd, gzip" -w "pck %{http_code} %{size_download}\n" http://localhost:8090/index.pck >> "C:\gemini cli\games\_prints\compose_logs.log" 2>&1
