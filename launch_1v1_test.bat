@echo off
echo ====================================================================
echo  INICIANDO TESTE 1V1 MULTIPLAYER LOCAL (CALL OF DUTY STYLE - NUKETOWN)
echo ====================================================================

set GODOT_EXE=C:\Users\lala\Desktop\Godot_v4.7.2-stable_win64.exe

if not exist "%GODOT_EXE%" (
    echo [ERRO] Executavel do Godot nao encontrado em: %GODOT_EXE%
    pause
    exit /b 1
)

echo Iniciando Instancia 1 (HOST - P1)...
start "" "%GODOT_EXE%" --path "%~dp0." --resolution 960x540 --position 50,100 "res://scenes/_world/map_nuketown_1v1.tscn" -- --host

ping -n 3 127.0.0.1 >nul

echo Iniciando Instancia 2 (CLIENT - P2)...
start "" "%GODOT_EXE%" --path "%~dp0." --resolution 960x540 --position 1000,100 "res://scenes/_world/map_nuketown_1v1.tscn" -- --client

echo Partida iniciada com sucesso!
