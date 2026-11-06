@echo off
netstat -ano | findstr ":7777" > "C:\gemini cli\games\_prints\port.log" 2>&1
powershell -NoProfile -Command "Get-CimInstance Win32_Process | Where-Object { $_.Name -like 'Godot*' -or $_.Name -like 'python*' } | Select-Object ProcessId,Name,CommandLine | Format-List" >> "C:\gemini cli\games\_prints\port.log" 2>&1
