# =============================================================================
# Dockerfile — Servidor Dedicado Godot 4 (NUKETOWN 1v1 até 6v6)
# =============================================================================
FROM ubuntu:22.04

# Evitar prompts interativos durante a instalação
ENV DEBIAN_FRONTEND=noninteractive

# Instalar bibliotecas essenciais para o runtime Linux do Godot 4
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    libfontconfig1 \
    libxcursor1 \
    libxinerama1 \
    libxrandr2 \
    libxi6 \
    libgl1 \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copia script de inicialização e binários
COPY entrypoint.sh /app/entrypoint.sh
# O executável exportado (bin/) é montado como volume no docker-compose: a imagem fica pequena
# e uma nova exportação vale com um simples "docker compose restart".

RUN sed -i 's/\r$//' /app/entrypoint.sh && chmod +x /app/entrypoint.sh

# Porta do WebSocket (TCP) - o Caddy faz o TLS (wss://) na frente
EXPOSE 7777/tcp

# Executar script de inicialização
ENTRYPOINT ["/app/entrypoint.sh"]
