@echo off
powershell -NoProfile -Command "$o=Get-CimInstance Win32_OperatingSystem; $d=Get-PSDrive C; \"RAM livre MB: \" + [int]($o.FreePhysicalMemory/1024) + \" de \" + [int]($o.TotalVisibleMemorySize/1024); \"Virtual livre MB: \" + [int]($o.FreeVirtualMemory/1024); \"Disco C livre GB: \" + [math]::Round($d.Free/1GB,1)" > "C:\gemini cli\games\_prints\mem2.txt"
