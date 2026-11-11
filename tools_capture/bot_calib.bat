@echo off
cd /d "C:\gemini cli\games"
"C:\Users\lala\Desktop\Godot_v4.7.2-stable_win64.exe" --path "C:\gemini cli\games" --resolution 960x720 res://tools_capture/bot_calib.tscn -- %* > "C:\gemini cli\games\_prints\bot_calib.log" 2>&1
