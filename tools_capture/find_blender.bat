@echo off
powershell -NoProfile -Command "Get-ChildItem 'C:\Program Files\Blender Foundation','C:\Program Files (x86)\Steam\steamapps\common\Blender','C:\Users\lala\Desktop','C:\Users\lala\AppData\Local' -Recurse -Filter blender.exe -ErrorAction SilentlyContinue -Depth 3 | Select-Object -ExpandProperty FullName" > "C:\gemini cli\games\_prints\blender_path.txt" 2>&1
