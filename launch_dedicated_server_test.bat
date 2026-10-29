@echo off
echo ====================================================================
echo  TESTE LOCAL: SERVIDOR DEDICADO HEADLESS + 2 CLIENTES (ATE 6V6)
echo ====================================================================

set GODOT_EXE=C:\Users\lala\Desktop\Godot_v4.7.2-stable_win64.exe

if not exist "%GODOT_EXE%" (
    echo [ERRO] Executavel do Godot nao encontrado em: %GODOT_EXE%
    pause
    exit /b 1
)

echo [1/3] Iniciando SERVIDOR DEDICADO HEADLESS (Porta 7777)...
start "NUKE Dedicated Server (Headless)" "%GODOT_EXE%" --headless --path "%~dp0." "res://scenes/_world/map_nuketown_1v1.tscn" -- --server --port=7777 --max-players=12 --target-kills=10

echo Aguardando servidor inicializar...
ping -n 3 127.0.0.1 >nul

echo [2/3] Conectando Jogador 1 (Time Alpha - CT)...
start "Jogador 1 (Alpha - CT)" "%GODOT_EXE%" --path "%~dp0." --resolution 960x540 --position 50,100 "res://scenes/_world/map_nuketown_1v1.tscn" -- --client --server-ip=127.0.0.1

ping -n 3 127.0.0.1 >nul

echo [3/3] Conectando Jogador 2 (Time Bravo - T)...
start "Jogador 2 (Bravo - T)" "%GODOT_EXE%" --path "%~dp0." --resolution 960x540 --position 1000,100 "res://scenes/_world/map_nuketown_1v1.tscn" -- --client --server-ip=127.0.0.1

echo.
echo ====================================================================
echo  Servidor e 2 jogadores conectados com sucesso via Servidor Dedicado!
echo ====================================================================
