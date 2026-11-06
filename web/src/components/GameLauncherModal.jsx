import React, { useState, useRef, useEffect } from 'react';
import { 
  X, Play, Shield, Wifi, Target, Crosshair, Sparkles, CheckCircle2, 
  RotateCcw, Monitor, Globe, Flame, Volume2, Maximize, AlertCircle, ExternalLink 
} from 'lucide-react';

export default function GameLauncherModal({ isOpen, onClose, selectedMode = '1v1', userGamertag = 'Operador_Alpha', walletAddress = '' }) {
  const [map, setMap] = useState('Nuketown 2065');
  const [mode, setMode] = useState(selectedMode);
  const [stake, setStake] = useState('10');
  const [server, setServer] = useState('São Paulo (18ms)');
  const [executionPlatform, setExecutionPlatform] = useState('web'); // 'web' | 'desktop'
  
  const [gameStarted, setGameStarted] = useState(false);
  const [desktopLaunched, setDesktopLaunched] = useState(false);
  const [isLaunchingDesktop, setIsLaunchingDesktop] = useState(false);
  const [sessionKey, setSessionKey] = useState(Date.now());
  const iframeContainerRef = useRef(null);
  // Resultado oficial da partida (vem do servidor, repassado pelo jogo dentro do iframe)
  const [matchResult, setMatchResult] = useState(null);

  useEffect(() => {
    const onMsg = (ev) => {
      if (ev.origin !== window.location.origin) return;
      const m = ev.data;
      if (m && m.source === 'nuke-game' && m.event === 'match_result') setMatchResult(m.data);
    };
    window.addEventListener('message', onMsg);
    return () => window.removeEventListener('message', onMsg);
  }, []);

  if (!isOpen) return null;

  // Convert friendly mode and map names to engine parameters
  const getModeCode = () => {
    if (mode.includes('6v6')) return '6v6';
    if (mode.includes('PvE') || mode.includes('pve')) return 'pve';
    return '1v1';
  };

  const getMapCode = () => {
    if (map.includes('Clássico') || map.includes('classic') || map.includes('BO1')) return 'nuketown_classic';
    if (map.includes('Hardhat')) return 'hardhat';
    return 'nuketown_2065';
  };

  const modeCode = getModeCode();
  const mapCode = getMapCode();
  // Onde está o jogo e o servidor da partida:
  //  - VITE_GAME_URL: página do jogo (padrão: /game/index.html deste site; no Docker: http://localhost:8090/index.html)
  //  - VITE_GAME_SERVER: host:porta do servidor dedicado (ex.: localhost:8090 ou play.seudominio.com:443).
  //    Se definido, os modos online (1v1/6v6) entram direto na partida do servidor; PvE continua local.
  const gameBase = import.meta.env.VITE_GAME_URL || '/game/index.html';
  const gameServer = import.meta.env.VITE_GAME_SERVER || '';
  const joinServer = gameServer && modeCode !== 'pve';
  const godotUrl = `${gameBase}?autostart=1&mode=${modeCode}&map=${mapCode}&stake=${stake}&player=${encodeURIComponent(userGamertag)}&wallet=${encodeURIComponent(walletAddress || '')}${joinServer ? `&server=${encodeURIComponent(gameServer)}` : ''}&_s=${sessionKey}`;

  const handleLaunchDesktop = async () => {
    setIsLaunchingDesktop(true);
    try {
      const response = await fetch('/api/launch', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          mode: modeCode,
          map: mapCode,
          stake: stake,
          player: userGamertag
        })
      });
      if (response.ok) {
        setDesktopLaunched(true);
        setGameStarted(false);
      }
    } catch (err) {
      console.error('Falha ao abrir cliente desktop:', err);
    } finally {
      setIsLaunchingDesktop(false);
    }
  };

  const handleStartGame = () => {
    if (executionPlatform === 'desktop') {
      handleLaunchDesktop();
    } else {
      setSessionKey(Date.now());
      setGameStarted(true);
    }
  };

  const handleToggleFullscreen = () => {
    if (!iframeContainerRef.current) return;
    if (!document.fullscreenElement) {
      iframeContainerRef.current.requestFullscreen().catch(err => {
        console.error("Erro ao ativar tela cheia:", err);
      });
    } else {
      document.exitFullscreen();
    }
  };

  return (
    <div className="modal-overlay" onClick={onClose} style={{ zIndex: 9999 }}>
      <div 
        className="modal-content" 
        onClick={(e) => e.stopPropagation()} 
        style={{
          maxWidth: gameStarted ? '1180px' : '760px',
          width: '95vw',
          padding: gameStarted ? '0' : '36px',
          transition: 'all 0.3s cubic-bezier(0.16, 1, 0.3, 1)',
          background: '#070a12',
          border: '1px solid rgba(0, 240, 255, 0.3)',
          boxShadow: '0 0 60px rgba(0, 240, 255, 0.15)',
          borderRadius: '16px',
          overflow: 'hidden',
          position: 'relative'
        }}
      >
        {/* Top Right Close Button */}
        <button 
          onClick={() => {
            setGameStarted(false);
            setDesktopLaunched(false);
            onClose();
          }}
          style={{
            position: 'absolute',
            top: '16px',
            right: '16px',
            background: 'rgba(0,0,0,0.7)',
            border: '1px solid rgba(255,255,255,0.15)',
            color: '#fff',
            borderRadius: '50%',
            width: '34px',
            height: '34px',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            cursor: 'pointer',
            zIndex: 100,
            transition: 'all 0.2s ease'
          }}
          onMouseEnter={(e) => e.currentTarget.style.borderColor = 'var(--cyan)'}
          onMouseLeave={(e) => e.currentTarget.style.borderColor = 'rgba(255,255,255,0.15)'}
        >
          <X size={18} />
        </button>

        {desktopLaunched ? (
          /* ========================================================================= */
          /* CLIENTE DESKTOP NATIVO INICIADO (120 FPS GODOT WIN64)                     */
          /* ========================================================================= */
          <div style={{ textAlign: 'center', padding: '48px 24px' }}>
            <div style={{
              width: '72px',
              height: '72px',
              borderRadius: '20px',
              background: 'linear-gradient(135deg, #00f0ff 0%, #14F195 100%)',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              margin: '0 auto 24px auto',
              boxShadow: '0 0 40px rgba(0, 240, 255, 0.4)'
            }}>
              <Monitor size={36} color="#000" />
            </div>

            <h3 className="font-display" style={{ fontSize: '2rem', fontWeight: 900, color: '#fff', marginBottom: '12px' }}>
              CLIENTE GODOT DESKTOP INICIADO!
            </h3>

            <p style={{ color: 'var(--text-muted)', fontSize: '1.05rem', maxWidth: '560px', margin: '0 auto 28px auto', lineHeight: 1.6 }}>
              A janela nativa oficial do Godot Engine foi iniciada no seu Windows com o mapa <strong style={{ color: 'var(--cyan)' }}>{map}</strong> no modo <strong style={{ color: 'var(--orange)' }}>{mode}</strong> rodando a 120 FPS com renderização Vulkan Forward+.
            </p>

            <div style={{
              background: 'rgba(12, 17, 28, 0.9)',
              border: '1px solid var(--border-cyan)',
              padding: '18px 28px',
              borderRadius: '10px',
              display: 'inline-block',
              marginBottom: '32px'
            }}>
              <div style={{ fontSize: '0.8rem', color: 'var(--cyan)', fontFamily: 'var(--font-tactical)', fontWeight: 800, letterSpacing: '0.05em' }}>
                PARÂMETROS DA SESSÃO ATIVA
              </div>
              <div style={{ fontSize: '1.1rem', fontWeight: 800, color: '#fff', marginTop: '4px' }}>
                Jogador: {userGamertag} • Aposta: ${stake} USDC • Servidor: {server}
              </div>
            </div>

            <div style={{ display: 'flex', gap: '14px', justifyContent: 'center' }}>
              <button 
                onClick={() => setDesktopLaunched(false)} 
                className="btn-secondary" 
                style={{ padding: '12px 26px', fontSize: '0.95rem' }}
              >
                Configurar Nova Partida
              </button>
              <button 
                onClick={onClose} 
                className="btn-primary" 
                style={{ padding: '12px 30px', fontSize: '0.95rem' }}
              >
                Fechar Janela
              </button>
            </div>
          </div>
        ) : gameStarted ? (
          /* ========================================================================= */
          /* GODOT 4.7 REAL WEB ENGINE (WASM / WEBGL 2.0 NO NAVEGADOR)                 */
          /* ========================================================================= */
          <div 
            ref={iframeContainerRef}
            style={{ 
              position: 'relative', 
              width: '100%', 
              height: '740px', 
              background: '#020408',
              display: 'flex',
              flexDirection: 'column'
            }}
          >
            {/* Top Tactical Status Header Bar */}
            <div style={{
              height: '52px',
              background: 'rgba(9, 13, 22, 0.98)',
              borderBottom: '1px solid rgba(0, 240, 255, 0.3)',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'space-between',
              padding: '0 20px',
              zIndex: 20
            }}>
              <div style={{ display: 'flex', alignItems: 'center', gap: '12px' }}>
                <div style={{
                  background: 'linear-gradient(135deg, #00f0ff 0%, #ff5500 100%)',
                  borderRadius: '6px',
                  padding: '4px 10px',
                  fontSize: '0.75rem',
                  fontWeight: 900,
                  color: '#000',
                  fontFamily: 'var(--font-display)',
                  letterSpacing: '0.05em'
                }}>
                  GODOT 4.7 REAL ENGINE
                </div>
                
                <div style={{ fontSize: '0.9rem', fontWeight: 800, color: '#fff', display: 'flex', alignItems: 'center', gap: '8px' }}>
                  <span style={{ color: 'var(--cyan)' }}>{map}</span>
                  <span style={{ color: 'var(--text-dim)' }}>•</span>
                  <span style={{ color: 'var(--orange)' }}>{mode}</span>
                  <span style={{ color: 'var(--text-dim)' }}>•</span>
                  <span style={{ color: 'var(--gold)' }}>{stake === '0' ? 'MODO DEMO' : `$${stake} USDC`}</span>
                </div>
              </div>

              {/* Action buttons on top bar */}
              <div style={{ display: 'flex', alignItems: 'center', gap: '10px' }}>
                <button
                  onClick={handleToggleFullscreen}
                  title="Ativar Tela Cheia"
                  style={{
                    display: 'flex',
                    alignItems: 'center',
                    gap: '6px',
                    padding: '6px 14px',
                    borderRadius: '6px',
                    background: 'rgba(255,255,255,0.06)',
                    border: '1px solid var(--border-subtle)',
                    color: '#fff',
                    fontSize: '0.8rem',
                    fontWeight: 700,
                    cursor: 'pointer'
                  }}
                >
                  <Maximize size={14} />
                  <span>Tela Cheia</span>
                </button>

                <button
                  onClick={() => window.open(godotUrl, '_blank')}
                  title="Abrir em Nova Aba Independente"
                  style={{
                    display: 'flex',
                    alignItems: 'center',
                    gap: '6px',
                    padding: '6px 14px',
                    borderRadius: '6px',
                    background: 'rgba(0, 240, 255, 0.1)',
                    border: '1px solid var(--border-cyan)',
                    color: 'var(--cyan)',
                    fontSize: '0.8rem',
                    fontWeight: 700,
                    cursor: 'pointer'
                  }}
                >
                  <ExternalLink size={14} />
                  <span>Nova Aba</span>
                </button>

                <button
                  onClick={handleLaunchDesktop}
                  title="Iniciar Cliente Desktop a 120 FPS"
                  style={{
                    display: 'flex',
                    alignItems: 'center',
                    gap: '6px',
                    padding: '6px 14px',
                    borderRadius: '6px',
                    background: 'rgba(255, 102, 0, 0.15)',
                    border: '1px solid var(--orange)',
                    color: 'var(--orange)',
                    fontSize: '0.8rem',
                    fontWeight: 700,
                    cursor: 'pointer'
                  }}
                >
                  <Monitor size={14} />
                  <span>Abrir Desktop</span>
                </button>

                <button
                  onClick={() => setGameStarted(false)}
                  style={{
                    padding: '6px 14px',
                    borderRadius: '6px',
                    background: 'rgba(255, 34, 85, 0.15)',
                    border: '1px solid var(--red)',
                    color: 'var(--red)',
                    fontSize: '0.8rem',
                    fontWeight: 700,
                    cursor: 'pointer'
                  }}
                >
                  Voltar ao Lobby
                </button>
              </div>
            </div>

            {/* REAL GODOT ENGINE IFRAME VIEWPORT */}
            <div style={{ flex: 1, position: 'relative', width: '100%', height: '100%', background: '#000' }}>
              {matchResult && matchResult.result && (
                <div style={{ position: 'absolute', top: 12, left: '50%', transform: 'translateX(-50%)', zIndex: 5, background: 'rgba(10,14,22,0.92)', border: '1px solid var(--gold)', borderRadius: 8, padding: '10px 16px', color: '#fff', fontSize: 13 }}>
                  Resultado oficial do servidor — partida {matchResult.result.match_id}: vitória do time {matchResult.result.winner_team === 0 ? 'ALPHA' : 'BRAVO'} ({matchResult.result.score.alpha} x {matchResult.result.score.bravo}){matchResult.signature ? ' • assinado' : ' • SEM assinatura'}
                </div>
              )}
              <iframe
                key={sessionKey}
                src={godotUrl}
                title="Godot 4.7 Engine - Nuke Tactical FPS"
                allow="autoplay; fullscreen; pointer-lock"
                style={{
                  width: '100%',
                  height: '100%',
                  border: 'none',
                  display: 'block'
                }}
              />
            </div>

            {/* Bottom Controls Info Banner */}
            <div style={{
              height: '36px',
              background: '#060910',
              borderTop: '1px solid rgba(255,255,255,0.08)',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'space-between',
              padding: '0 20px',
              fontSize: '0.78rem',
              color: 'var(--text-muted)'
            }}>
              <div>
                🎯 <strong style={{ color: '#fff' }}>Controles FPS:</strong> Clique dentro do jogo para travar o mouse (Pointer Lock). Pressione <strong style={{ color: 'var(--cyan)' }}>ESC</strong> para soltar o cursor.
              </div>
              <div style={{ color: 'var(--green)', display: 'flex', alignItems: 'center', gap: '6px', fontWeight: 700 }}>
                <span className="pulse-dot" />
                Motor Godot 4.7 WebGL 2.0 Ativo
              </div>
            </div>
          </div>
        ) : (
          /* ========================================================================= */
          /* CENTRO DE DEPLOY TÁTICO (LOBBY OFICIAL ANTES DO INÍCIO)                   */
          /* ========================================================================= */
          <div>
            <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: '24px' }}>
              <div style={{ display: 'flex', alignItems: 'center', gap: '14px' }}>
                <div style={{
                  width: '50px',
                  height: '50px',
                  borderRadius: '14px',
                  background: 'linear-gradient(135deg, #00f0ff 0%, #ff5500 100%)',
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'center',
                  color: '#000',
                  boxShadow: '0 0 25px rgba(0, 240, 255, 0.35)'
                }}>
                  <Play size={24} fill="#000" />
                </div>
                <div>
                  <h3 className="font-display" style={{ fontSize: '1.6rem', fontWeight: 900, color: '#fff', letterSpacing: '0.02em' }}>
                    CENTRO DE DEPLOY TÁTICO
                  </h3>
                  <div style={{ fontSize: '0.85rem', color: 'var(--text-muted)' }}>
                    Conectando ao Godot 4.7 oficial: escolha o modo, mapa e plataforma de execução.
                  </div>
                </div>
              </div>

              {/* Execution Platform Selector */}
              <div style={{
                display: 'flex',
                background: 'rgba(15, 20, 32, 0.95)',
                borderRadius: '8px',
                padding: '4px',
                border: '1px solid var(--border-subtle)'
              }}>
                <button
                  onClick={() => setExecutionPlatform('web')}
                  style={{
                    display: 'flex',
                    alignItems: 'center',
                    gap: '6px',
                    padding: '8px 16px',
                    borderRadius: '6px',
                    border: 'none',
                    background: executionPlatform === 'web' ? 'rgba(0, 240, 255, 0.2)' : 'transparent',
                    color: executionPlatform === 'web' ? '#fff' : 'var(--text-dim)',
                    fontFamily: 'var(--font-tactical)',
                    fontWeight: 800,
                    fontSize: '0.82rem',
                    cursor: 'pointer',
                    transition: 'var(--transition)'
                  }}
                >
                  <Globe size={15} color={executionPlatform === 'web' ? 'var(--cyan)' : 'inherit'} />
                  <span>Navegador (WebGL)</span>
                </button>
                <button
                  onClick={() => setExecutionPlatform('desktop')}
                  style={{
                    display: 'flex',
                    alignItems: 'center',
                    gap: '6px',
                    padding: '8px 16px',
                    borderRadius: '6px',
                    border: 'none',
                    background: executionPlatform === 'desktop' ? 'rgba(0, 240, 255, 0.2)' : 'transparent',
                    color: executionPlatform === 'desktop' ? '#fff' : 'var(--text-dim)',
                    fontFamily: 'var(--font-tactical)',
                    fontWeight: 800,
                    fontSize: '0.82rem',
                    cursor: 'pointer',
                    transition: 'var(--transition)'
                  }}
                >
                  <Monitor size={15} color={executionPlatform === 'desktop' ? 'var(--cyan)' : 'inherit'} />
                  <span>Desktop (120 FPS)</span>
                </button>
              </div>
            </div>

            {/* Mode selection */}
            <div style={{ marginBottom: '20px' }}>
              <label style={{ display: 'block', fontSize: '0.75rem', color: 'var(--text-dim)', fontFamily: 'var(--font-tactical)', fontWeight: 800, marginBottom: '8px', letterSpacing: '0.05em' }}>
                MODO DE COMBATE OFICIAL:
              </label>
              <div style={{ display: 'grid', gridTemplateColumns: 'repeat(3, 1fr)', gap: '10px' }}>
                {[
                  { id: '1v1', label: '1v1 WAGER', desc: 'Duelo 10 Kills • Sudden Death 9x9' },
                  { id: '6v6', label: '6v6 TEAM TDM', desc: '12 Operadores • Prêmio MVP' },
                  { id: 'pve', label: 'PVE BOTS ARENA', desc: 'Treino & Farm de $NUKE' }
                ].map((m) => (
                  <button
                    key={m.id}
                    onClick={() => setMode(m.label)}
                    style={{
                      padding: '14px 12px',
                      borderRadius: '8px',
                      background: mode === m.label ? 'rgba(0, 240, 255, 0.16)' : 'rgba(15, 20, 32, 0.7)',
                      border: mode === m.label ? '1px solid var(--cyan)' : '1px solid var(--border-subtle)',
                      color: mode === m.label ? '#fff' : 'var(--text-dim)',
                      textAlign: 'left',
                      cursor: 'pointer',
                      transition: 'var(--transition)'
                    }}
                  >
                    <div style={{ fontFamily: 'var(--font-display)', fontWeight: 900, fontSize: '0.9rem', color: mode === m.label ? 'var(--cyan)' : '#fff' }}>
                      {m.label}
                    </div>
                    <div style={{ fontSize: '0.72rem', color: 'var(--text-dim)', marginTop: '4px' }}>
                      {m.desc}
                    </div>
                  </button>
                ))}
              </div>
            </div>

            {/* Map selection */}
            <div style={{ marginBottom: '20px' }}>
              <label style={{ display: 'block', fontSize: '0.75rem', color: 'var(--text-dim)', fontFamily: 'var(--font-tactical)', fontWeight: 800, marginBottom: '8px', letterSpacing: '0.05em' }}>
                MAPA MULTIPLAYER:
              </label>
              <div style={{ display: 'grid', gridTemplateColumns: 'repeat(3, 1fr)', gap: '10px' }}>
                {[
                  { name: 'Nuketown 2065', era: 'Futurista BO3 (3D Real)', disabled: false },
                  { name: 'Nuketown Clássico', era: 'Retro BO1 (1960)', disabled: false },
                  { name: 'Hardhat Arena', era: 'EM BREVE', disabled: true }
                ].map((mp) => (
                  <button
                    key={mp.name}
                    disabled={mp.disabled}
                    onClick={() => !mp.disabled && setMap(mp.name)}
                    style={{
                      padding: '14px 12px',
                      borderRadius: '8px',
                      background: map === mp.name ? 'rgba(255, 102, 0, 0.16)' : 'rgba(15, 20, 32, 0.7)',
                      border: map === mp.name ? '1px solid var(--orange)' : '1px solid var(--border-subtle)',
                      color: mp.disabled ? 'var(--text-dim)' : (map === mp.name ? '#fff' : 'var(--text-dim)'),
                      textAlign: 'left',
                      cursor: mp.disabled ? 'not-allowed' : 'pointer',
                      opacity: mp.disabled ? 0.45 : 1,
                      transition: 'var(--transition)'
                    }}
                  >
                    <div style={{ fontFamily: 'var(--font-tactical)', fontWeight: 900, fontSize: '0.9rem', color: mp.disabled ? 'var(--text-dim)' : (map === mp.name ? 'var(--orange)' : '#fff') }}>
                      {mp.name}
                    </div>
                    <div style={{ fontSize: '0.72rem', color: mp.disabled ? 'var(--orange)' : 'var(--text-dim)', marginTop: '4px', fontWeight: mp.disabled ? 800 : 400 }}>
                      {mp.era}
                    </div>
                  </button>
                ))}
              </div>
            </div>

            {/* Stake selection */}
            <div style={{ marginBottom: '24px' }}>
              <label style={{ display: 'block', fontSize: '0.75rem', color: 'var(--text-dim)', fontFamily: 'var(--font-tactical)', fontWeight: 800, marginBottom: '8px', letterSpacing: '0.05em' }}>
                VALOR DA APOSTA (WAGER STAKE):
              </label>
              <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: '10px' }}>
                {[
                  { label: 'GRÁTIS (DEMO)', val: '0' },
                  { label: '$2 USDC', val: '2' },
                  { label: '$10 USDC', val: '10' },
                  { label: '$50 (VIP)', val: '50' }
                ].map((s) => (
                  <button
                    key={s.val}
                    onClick={() => setStake(s.val)}
                    style={{
                      padding: '12px 8px',
                      borderRadius: '8px',
                      background: stake === s.val ? 'rgba(255, 215, 0, 0.2)' : 'rgba(15, 20, 32, 0.7)',
                      border: stake === s.val ? '1px solid var(--gold)' : '1px solid var(--border-subtle)',
                      color: stake === s.val ? '#fff' : 'var(--text-dim)',
                      fontFamily: 'var(--font-display)',
                      fontWeight: 800,
                      fontSize: '0.85rem',
                      cursor: 'pointer',
                      transition: 'var(--transition)'
                    }}
                  >
                    {s.label}
                  </button>
                ))}
              </div>
            </div>

            {/* Server specs bar */}
            <div style={{
              background: 'rgba(7, 10, 16, 0.8)',
              border: '1px solid var(--border-subtle)',
              padding: '12px 20px',
              borderRadius: '8px',
              display: 'flex',
              justifyContent: 'space-between',
              alignItems: 'center',
              marginBottom: '26px'
            }}>
              <div style={{ display: 'flex', alignItems: 'center', gap: '8px', fontSize: '0.85rem', color: 'var(--text-muted)' }}>
                <Wifi size={16} color="var(--green)" />
                <span>Servidor: <strong style={{ color: '#fff' }}>{server}</strong></span>
              </div>
              <div style={{ display: 'flex', alignItems: 'center', gap: '6px', fontSize: '0.8rem', color: 'var(--cyan)' }}>
                <Shield size={14} />
                <span>Tickrate 60Hz • Anti-Cheat Ativo</span>
              </div>
            </div>

            {/* Platform Feature Notice */}
            <div style={{
              background: 'rgba(0, 240, 255, 0.05)',
              border: '1px solid rgba(0, 240, 255, 0.2)',
              borderRadius: '8px',
              padding: '12px 16px',
              marginBottom: '24px',
              fontSize: '0.82rem',
              color: 'var(--text-muted)',
              display: 'flex',
              alignItems: 'center',
              gap: '10px'
            }}>
              <AlertCircle size={18} color="var(--cyan)" style={{ flexShrink: 0 }} />
              <div>
                {executionPlatform === 'web' ? (
                  <span>
                    Executando o motor <strong>Godot 4.7 WebAssembly</strong> real com suporte a WebGL 2.0 e captura total de mouse FPS.
                  </span>
                ) : (
                  <span>
                    O cliente nativo desktop abre em janela dedicada no Windows com taxa máxima de <strong>120 FPS</strong> e renderização <strong>Vulkan Forward+</strong>.
                  </span>
                )}
              </div>
            </div>

            {/* Main Launch Action Button */}
            <div style={{ display: 'flex', gap: '12px' }}>
              <button
                onClick={handleStartGame}
                disabled={isLaunchingDesktop}
                className="btn-primary"
                style={{ flex: 1, padding: '16px', fontSize: '1.05rem', justifyContent: 'center' }}
              >
                {executionPlatform === 'desktop' ? (
                  <>
                    <Monitor size={20} color="#000" />
                    <span>{isLaunchingDesktop ? 'LANÇANDO GODOT DESKTOP...' : 'LANÇAR CLIENTE DESKTOP (120 FPS)'}</span>
                  </>
                ) : (
                  <>
                    <Play size={20} fill="#000" />
                    <span>INICIAR GODOT WEB NO NAVEGADOR</span>
                  </>
                )}
              </button>

              {executionPlatform === 'web' && (
                <button
                  onClick={() => window.open(godotUrl, '_blank')}
                  title="Abrir diretamente em uma nova aba em tela inteira"
                  className="btn-secondary"
                  style={{ padding: '16px 20px', display: 'flex', alignItems: 'center', gap: '8px' }}
                >
                  <ExternalLink size={18} />
                  <span>Nova Aba</span>
                </button>
              )}
            </div>

          </div>
        )}

      </div>
    </div>
  );
}
