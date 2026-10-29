#!/bin/bash
set -e

PORT=${PORT:-7777}
MAX_PLAYERS=${MAX_PLAYERS:-12}
TARGET_KILLS=${TARGET_KILLS:-50}

echo "=========================================================="
echo "  INICIANDO SERVIDOR DEDICADO GODOT 4"
echo "  PORTA: ${PORT} (WebSocket/TCP)"
echo "  MAX JOGADORES: ${MAX_PLAYERS} (Suporta 1v1 até 6v6)"
echo "  META DE KILLS: ${TARGET_KILLS}"
echo "=========================================================="

if [ ! -f /app/bin/server.x86_64 ]; then
    echo "[ERRO] Executavel /app/bin/server.x86_64 nao encontrado!"
    echo "Certifique-se de exportar o projeto no Godot para a pasta server/bin/ antes do build."
    exit 1
fi

exec /app/bin/server.x86_64 --headless --server --port=${PORT} --max-players=${MAX_PLAYERS} --target-kills=${TARGET_KILLS}
