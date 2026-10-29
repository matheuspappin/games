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
COPY bin/ /app/bin/

RUN chmod +x /app/entrypoint.sh && \
    if [ -f /app/bin/server.x86_64 ]; then chmod +x /app/bin/server.x86_64; fi

# Porta de rede do ENet (UDP)
EXPOSE 7777/udp

# Executar script de inicialização
ENTRYPOINT ["/app/entrypoint.sh"]
