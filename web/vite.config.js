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
              const data = JSON.parse(body || '{}')
              const mode = data.mode || '1v1'
              const map = data.map || 'nuketown_2065'
              const stake = data.stake || '10'
              const player = data.player || 'Operador_Alpha'
              
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
  server: {
    headers: {
      'Cross-Origin-Opener-Policy': 'same-origin',
      'Cross-Origin-Embedder-Policy': 'require-corp',
    },
  },
  preview: {
    headers: {
      'Cross-Origin-Opener-Policy': 'same-origin',
      'Cross-Origin-Embedder-Policy': 'require-corp',
    },
  },
})
