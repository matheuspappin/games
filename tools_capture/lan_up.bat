@echo off
powershell -NoProfile -Command "Get-CimInstance Win32_Process | Where-Object { $_.Name -like 'Godot*' -and $_.CommandLine -like '*net_probe*' } | ForEach-Object { Stop-Process -Id $_.ProcessId -Force }"
cd /d "C:\gemini cli\games\server"
docker compose -f docker-compose.yml -f docker-compose.local.yml up -d > "C:\gemini cli\games\_prints\lan_up.log" 2>&1
echo FIM %ERRORLEVEL% >> "C:\gemini cli\games\_prints\lan_up.log"
powershell -NoProfile -Command "Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.IPAddress -notlike '127.*' -and $_.IPAddress -notlike '169.254*' -and $_.InterfaceAlias -notlike '*WSL*' -and $_.InterfaceAlias -notlike '*vEthernet*' } | ForEach-Object { 'IP ' + $_.InterfaceAlias + ' ' + $_.IPAddress }; Get-NetFirewallRule -Enabled True -Direction Inbound -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like '*Docker*' } | Select-Object -First 5 | ForEach-Object { 'FW ' + $_.DisplayName + ' ' + $_.Action }" >> "C:\gemini cli\games\_prints\lan_up.log" 2>&1
curl -s -o nul -w "local %%{http_code}\n" http://localhost:8090/index.html >> "C:\gemini cli\games\_prints\lan_up.log" 2>&1
