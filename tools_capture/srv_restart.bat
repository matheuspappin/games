@echo off
cd /d "C:\gemini cli\games\server"
docker restart nuke_dedicated_server > "C:\gemini cli\games\_prints\srv_restart.log" 2>&1
timeout /t 15 /nobreak > nul
docker logs --tail 25 nuke_dedicated_server >> "C:\gemini cli\games\_prints\srv_restart.log" 2>&1
curl -s -o nul -w "local8090 %%{http_code}\n" http://localhost:8090/index.html >> "C:\gemini cli\games\_prints\srv_restart.log" 2>&1
curl -sk -o nul -w "lan8443 %%{http_code}\n" https://192.168.15.15:8443/index.html >> "C:\gemini cli\games\_prints\srv_restart.log" 2>&1
powershell -NoProfile -Command "Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.IPAddress -notlike '127.*' -and $_.IPAddress -notlike '169.254*' -and $_.InterfaceAlias -notlike '*WSL*' -and $_.InterfaceAlias -notlike '*vEthernet*' } | ForEach-Object { 'IP ' + $_.InterfaceAlias + ' ' + $_.IPAddress }; Get-NetFirewallRule -DisplayName 'NukeFPS*' -ErrorAction SilentlyContinue | ForEach-Object { 'FW ' + $_.DisplayName + ' ' + $_.Enabled }" >> "C:\gemini cli\games\_prints\srv_restart.log" 2>&1
echo FIM >> "C:\gemini cli\games\_prints\srv_restart.log"
