@echo off
powershell -NoProfile -Command "Get-CimInstance Win32_Process | Where-Object { $_.CommandLine -like '*-- --server*' -and $_.Name -like 'Godot*' } | ForEach-Object { Stop-Process -Id $_.ProcessId -Force }; $os=Get-CimInstance Win32_OperatingSystem; 'RAM livre: {0:N1} GB' -f ($os.FreePhysicalMemory/1MB)" > "C:\gemini cli\games\_prints\ram.log" 2>&1
call "C:\gemini cli\games\tools_capture\menu_test.bat"
