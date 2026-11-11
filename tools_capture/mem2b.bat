@echo off
powershell -NoProfile -Command "$o=Get-CimInstance Win32_OperatingSystem; 'livre MB: ' + [int]($o.FreePhysicalMemory/1024); Get-Process | Sort-Object WS -Descending | Select-Object -First 12 Name,Id,@{n='MB';e={[int]($_.WS/1MB)}} | Format-Table -AutoSize | Out-String" > "C:\gemini cli\games\_prints\mem.txt" 2>&1
