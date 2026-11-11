@echo off
cd /d "C:\gemini cli\games"
"C:\Users\lala\Desktop\Godot_v4.7.2-stable_win64.exe" --path "C:\gemini cli\games" --resolution 1280x720 res://tools_capture/bot_smoke.tscn -- %* > "C:\gemini cli\games\_prints\bot_smoke.log" 2>&1
