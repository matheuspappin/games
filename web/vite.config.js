import react from '@vitejs/plugin-react'
import { defineConfig } from 'vite'
import { spawn } from 'child_process'
import path from 'path'

function godotLauncherPlugin() {
  return {
    name: 'godot-launcher',
    configureServer(server) {
      server.middlewares.use('/api/launch', (req, res) => {
        if (req.method === 'POST') {
          let body = ''
          req.on('data', chunk => { body += chunk })
          req.on('end', () => {
            try {
              const remote = req.socket.remoteAddress || ''
              if (!['127.0.0.1', '::1', '::ffff:127.0.0.1'].includes(remote)) {
                res.statusCode = 403
                return res.end(JSON.stringify({ error: 'somente localhost' }))
              }
              const data = JSON.parse(body || '{}')
              const safe = (v, re, d) => (typeof v === 'string' && re.test(v) ? v : d)
              const mode = safe(data.mode, /^[a-z0-9_]{1,16}$/i, '1v1')
              const map = safe(data.map, /^[a-z0-9_]{1,32}$/i, 'nuketown_2065')
              const stake = safe(String(data.stake ?? ''), /^\d{1,6}(\.\d{1,2})?$/, '10')
              const player = safe(data.player, /^[a-z0-9_]{1,24}$/i, 'Operador_Alpha')
              
              const batPath = path.resolve('..', 'launch_game.bat')
              spawn('cmd.exe', ['/c', batPath, mode, map, stake, player], {
                detached: true,
                stdio: 'ignore'
              }).unref()

              res.setHeader('Content-Type', 'application/json')
              res.end(JSON.stringify({ status: 'launched', mode, map, stake, player }))
            } catch (err) {
              res.statusCode = 500
              res.end(JSON.stringify({ error: err.message }))
            }
          })
        } else {
          res.statusCode = 405
          res.end('Method Not Allowed')
        }
      })
    }
  }
}

// https://vite.dev/config/
export default defineConfig({
  plugins: [react(), godotLauncherPlugin()],
  // Sem COOP/COEP: o build web e single-threaded (nao precisa de SharedArrayBuffer),
  // e esses cabecalhos bloqueiam as janelas das carteiras (Phantom, Solflare, WalletConnect).
  server: {
    headers: {
      'Cross-Origin-Opener-Policy': 'same-origin-allow-popups',
    },
  },
  preview: {
    headers: {
      'Cross-Origin-Opener-Policy': 'same-origin-allow-popups',
    },
  },
})
