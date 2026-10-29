@echo off
set MODE=%1
if "%MODE%"=="" set MODE=1v1
set MAP=%2
if "%MAP%"=="" set MAP=nuketown_2065
set STAKE=%3
if "%STAKE%"=="" set STAKE=10
set PLAYER=%4
if "%PLAYER%"=="" set PLAYER=Operador_Alpha

echo ========================================================
echo   NUKE TACTICAL FPS - INICIANDO SESSAO COMPETITIVA
echo ========================================================
echo   Modo:    %MODE%
echo   Mapa:    %MAP%
echo   Aposta:  $%STAKE% USDC
echo   Jogador: %PLAYER%
echo ========================================================

start "" "C:\Users\lala\Desktop\Godot_v4.7.2-stable_win64.exe" --path "c:\gemini cli\games" --auto-launch --mode=%MODE% --map=%MAP% --stake=%STAKE% --player=%PLAYER%
