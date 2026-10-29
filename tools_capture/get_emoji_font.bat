@echo off
powershell -NoProfile -Command "try { Invoke-WebRequest -UseBasicParsing -Uri 'https://github.com/google/fonts/raw/main/ofl/notoemoji/NotoEmoji%%5Bwght%%5D.ttf' -OutFile 'C:\gemini cli\games\assets\fonts\noto_emoji\NotoEmoji.ttf'; 'OK' } catch { $_.Exception.Message }" > "C:\gemini cli\games\_prints\emoji_dl.log" 2>&1
echo FIM >> "C:\gemini cli\games\_prints\emoji_dl.log"
