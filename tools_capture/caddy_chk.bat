@echo off
curl -skv --ssl-no-revoke -o nul -w "https_ip %%{http_code}\n" https://192.168.15.15:8443/index.html > "C:\gemini cli\games\_prints\caddy_chk.log" 2>&1
curl -sk --ssl-no-revoke -o nul -w "https_local %%{http_code}\n" https://localhost:8443/index.html >> "C:\gemini cli\games\_prints\caddy_chk.log" 2>&1
