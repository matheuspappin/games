# 🚀 Guia de Deploy: Servidor Dedicado Godot 4 com Docker (Até 6v6)

Este guia explica como exportar o servidor dedicado do Godot e executá-lo em uma máquina na nuvem (VPS / Docker) para partidas online de 1v1 até 6v6.

---

## 1. Exportando o Servidor Dedicado no Godot

1. Abra o projeto no **Godot Editor**.
2. Vá no menu: `Projeto` > `Exportar...`.
3. Selecione o preset **`Linux Dedicated Server`** (já pré-configurado no projeto).
4. Clique em **`Exportar Projeto...`**.
5. Salve o arquivo como:
   * **Caminho:** `server/bin/server.x86_64`
   * Certifique-se de que a opção **"Exportar com Debug"** esteja desmarcada para ambiente de produção (ou marcada para testar logs de depuração).

Após exportar, a pasta `server/bin/` conterá os arquivos:
```
server/bin/
├── server.x86_64
└── server.pck (se não embutido)
```

---

## 2. Preparando a VPS na Nuvem

Você pode usar qualquer provedor de VPS (Oracle Cloud Always Free, Hetzner, DigitalOcean, AWS Lightsail, Linode).

### Requisitos Mínimos da VPS:
* **SO:** Ubuntu 22.04 LTS ou Debian 12
* **Recursos:** 1 vCPU, 1 GB RAM (o servidor dedicado do Godot consome menos de 150 MB)
* **Docker & Docker Compose instalados:**
  ```bash
  curl -fsSL https://get.docker.com | sh
  sudo usermod -aG docker $USER
  ```

---

## 3. Liberando a Porta 7777 (UDP)

O protocolo de rede multiplayer do Godot (ENet) opera sobre **UDP**.

### No Firewall do Linux (UFW):
```bash
sudo ufw allow 7777/udp
sudo ufw reload
```

### No Painel da Nuvem (Ex: Oracle Cloud / AWS Security Group):
* Crie uma regra de entrada (*Ingress Rule*):
  * **Protocolo:** UDP
  * **Porta de Destino:** 7777
  * **Origem:** `0.0.0.0/0` (Qualquer IP)

---

## 4. Enviando os Arquivos e Iniciando o Container

1. Na sua máquina local, copie a pasta `server` para a sua VPS via SCP ou Rsync:
   ```bash
   scp -r server/ usuario@SEU_IP_VPS:/home/usuario/nuke_server
   ```

2. Na VPS, entre na pasta e inicialize o container:
   ```bash
   cd /home/usuario/nuke_server
   docker compose up -d --build
   ```

3. Verifique os logs em tempo real:
   ```bash
   docker compose logs -f
   ```
   Você verá a mensagem:
   ```
   [NetworkManager] SERVIDOR DEDICADO ONLINE NA PORTA 7777 (UDP)
   [NetworkManager] Capacidade Máxima: 12 jogadores (Suporta até 6v6)
   [NetworkManager] Meta da Partida: 50 Kills
   ```

---

## 5. Como os Jogadores Conectam

### Opção A: Linha de Comando / Atalho do Cliente
Crie um atalho do jogo para os jogadores com o IP público da VPS:
```bash
Jogo.exe --client --server-ip=SEU_IP_VPS
```

### Opção B: Pelo Menu / HUD do Jogo
1. O jogador abre o jogo normalmente.
2. No painel de conexão (`ConnectionPanel`), digita o IP público da VPS (ex: `142.93.120.45`).
3. Clica em **JOIN**.
4. O servidor automaticamente:
   * Aloca o jogador na equipe com menos membros (Alpha/CT ou Bravo/T);
   * Spawna o personagem na base correta de Nuketown;
   * Sincroniza posições, tiros e placar em tempo real.
