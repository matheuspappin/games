# Deploy: jogo no navegador + servidor dedicado (Docker)

Tudo roda em **um endereço só**: o Caddy entrega a página do jogo (exportado para Web) e
encaminha o WebSocket da partida para o servidor dedicado do Godot. O navegador não abre
UDP, então a rede do jogo é **WebSocket/TCP** (não ENet/UDP).

```
navegador ──https──► Caddy :443 ─┬─ arquivos  ─► /srv/game  (web/public/game)
          ──wss────►              └─ WebSocket ─► nuke-dedicated-server:7777
```

## 1. Exportar (sempre cliente e servidor juntos)

Cliente e servidor precisam ser da mesma versão (RPCs e sincronização mudam entre versões).

- Windows: `tools_capture\export_all.bat` (servidor + web). Feche o Docker Desktop antes se a
  máquina tiver pouca RAM — a exportação usa vários GB.
- Ou no editor: `Projeto > Exportar`:
  - **Linux Dedicated Server** → `server/bin/server.x86_64` (modo servidor dedicado, visuais removidos)
  - **Web** → `web/public/game/index.html` e **Web BO3 Pack** → `web/public/game/maps_bo3.pck`

## 2. Teste local no PC (http://localhost:8090)

Na pasta `server`:

```bash
docker compose -f docker-compose.yml -f docker-compose.local.yml up -d --build
```

Abra `http://localhost:8090` no navegador. No menu do jogo, **Servidor dedicado** já vem
preenchido com o endereço da página. Para um segundo jogador na mesma rede, abra
`http://IP-DO-PC:8090` em outro computador.

Logs: `docker compose logs -f nuke-dedicated-server`.

## 3. Produção (VPS com domínio)

1. DNS: `play.seudominio.com` → IP da VPS.
2. Firewall: liberar **TCP 80 e 443** (não precisa UDP nem 7777).
3. Na VPS, com a pasta do projeto (`server/` e `web/public/game/`):

```bash
export GAME_DOMAIN=play.seudominio.com
export MATCH_SECRET="$(openssl rand -hex 32)"   # guarde: valida os resultados
docker compose up -d --build
```

O Caddy emite o certificado HTTPS sozinho; o cliente usa `wss://` automaticamente.

## 4. Resultado das partidas (base das apostas)

- O **servidor é o único que aplica dano, conta kills e decide o vencedor**. O cliente só
  informa "atirei daqui, nesta direção, com esta arma"; o servidor confere (vivo, arma da
  classe, origem perto da cabeça, cadência) e refaz o tiro.
- No fim da partida o servidor grava `results/<match_id>.json` com o placar, os jogadores e
  a carteira informada por cada um, assinado com **HMAC-SHA256** usando `MATCH_SECRET`.
  Os arquivos ficam em `https://SEU_DOMINIO/results/<match_id>.json`.
- Verificação (oráculo/backend): `HMAC_SHA256(MATCH_SECRET, payload) == signature`.
- A carteira é **declarada** pela página (`?wallet=`). Antes de pagar alguém, o backend
  precisa provar a posse (assinatura de mensagem pela carteira no site).

## 5. Limites conhecidos

- Sem compensação de latência: com ping alto o servidor pode recusar tiros que acertaram na
  tela do jogador.
- Download do jogo: ~530 MB sem compressão (o Caddy comprime na transferência). Para
  produção, vale reduzir texturas e separar mapas sob demanda.
