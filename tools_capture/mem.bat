@echo off
wmic OS get FreePhysicalMemory,TotalVisibleMemorySize /value > "C:\gemini cli\games\_prints\mem.txt"
wmic logicaldisk where "DeviceID='C:'" get FreeSpace /value >> "C:\gemini cli\games\_prints\mem.txt"
tasklist /fi "imagename eq blender.exe" >> "C:\gemini cli\games\_prints\mem.txt"
tasklist /fi "imagename eq Godot_v4.7.2-stable_win64.exe" >> "C:\gemini cli\games\_prints\mem.txt"
