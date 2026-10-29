import React from 'react';
import { Shield, Flame, ExternalLink, Heart } from 'lucide-react';

export default function Footer() {
  return (
    <footer style={{
      background: '#040609',
      borderTop: '1px solid var(--border-subtle)',
      padding: '80px 0 40px 0',
      position: 'relative',
      zIndex: 10
    }}>
      <div className="container">
        
        {/* Top Grid */}
        <div style={{
          display: 'grid',
          gridTemplateColumns: 'repeat(auto-fit, minmax(220px, 1fr))',
          gap: '40px',
          marginBottom: '60px'
        }}>
          
          {/* Brand Info */}
          <div>
            <div style={{ display: 'flex', alignItems: 'center', gap: '10px', marginBottom: '16px' }}>
              <div style={{
                width: '36px',
                height: '36px',
                borderRadius: '8px',
                background: 'linear-gradient(135deg, #00f0ff 0%, #ff5500 100%)',
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'center',
                boxShadow: '0 0 16px rgba(0, 240, 255, 0.4)'
              }}>
                <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="#000" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round">
                  <circle cx="12" cy="12" r="3"></circle>
                  <path d="M12 3v3m0 12v3M3 12h3m12 0h3"></path>
                </svg>
              </div>
              <span className="font-display" style={{ fontSize: '1.4rem', fontWeight: 900, color: '#fff' }}>
                NUKE
              </span>
            </div>
            <p style={{ color: 'var(--text-muted)', fontSize: '0.9rem', lineHeight: 1.6, marginBottom: '20px' }}>
              O primeiro FPS tático 3D jogável direto no navegador com apostas de habilidade em Solana ($NUKE). Duelos 1v1, 6v6 e bots PvE monetizados.
            </p>
            <div style={{ display: 'flex', gap: '12px' }}>
              <a href="https://x.com" target="_blank" rel="noreferrer" className="social-icon">𝕏</a>
              <a href="https://telegram.org" target="_blank" rel="noreferrer" className="social-icon">✈️</a>
              <a href="https://discord.com" target="_blank" rel="noreferrer" className="social-icon">💬</a>
              <a href="https://pump.fun" target="_blank" rel="noreferrer" className="social-icon">💊</a>
            </div>
          </div>

          {/* Links 1: Jogo */}
          <div>
            <h4 className="font-tactical" style={{ color: 'var(--cyan)', fontSize: '1rem', fontWeight: 800, marginBottom: '18px' }}>
              ECOSSISTEMA DE JOGO
            </h4>
            <div style={{ display: 'flex', flexDirection: 'column', gap: '10px' }}>
              <a href="#maps" className="footer-link">Nuketown 2065 (BO3)</a>
              <a href="#maps" className="footer-link">Nuketown Clássico (BO1)</a>
              <a href="#modes" className="footer-link">Duelos 1v1 High Stakes</a>
              <a href="#modes" className="footer-link">Torneios 6v6 Sit & Go</a>
              <a href="#modes" className="footer-link">Treino PvE com Bots</a>
            </div>
          </div>

          {/* Links 2: Tecnologia */}
          <div>
            <h4 className="font-tactical" style={{ color: 'var(--cyan)', fontSize: '1rem', fontWeight: 800, marginBottom: '18px' }}>
              TECNOLOGIA & SEGURANÇA
            </h4>
            <div style={{ display: 'flex', flexDirection: 'column', gap: '10px' }}>
              <a href="#anticheat" className="footer-link">Servidor Autoritativo 60Hz</a>
              <a href="#anticheat" className="footer-link">Anti-Wallhack Fog of War</a>
              <a href="#anticheat" className="footer-link">Detecção Biométrica de Aimbot</a>
              <a href="#tokenomics" className="footer-link">Smart Contract de Escrow</a>
              <a href="#tokenomics" className="footer-link">Oráculo Criptográfico</a>
            </div>
          </div>

          {/* Links 3: Token */}
          <div>
            <h4 className="font-tactical" style={{ color: 'var(--gold)', fontSize: '1rem', fontWeight: 800, marginBottom: '18px' }}>
              TOKENOMICS $NUKE
            </h4>
            <div style={{ display: 'flex', flexDirection: 'column', gap: '10px' }}>
              <a href="https://pump.fun" target="_blank" rel="noreferrer" className="footer-link">
                Bonding Curve no pump.fun <ExternalLink size={12} style={{ display: 'inline', marginLeft: '4px' }} />
              </a>
              <a href="https://raydium.io" target="_blank" rel="noreferrer" className="footer-link">
                Raydium DEX (Pós-migração)
              </a>
              <a href="#projections" className="footer-link">Queima Deflacionária (50%)</a>
              <a href="#projections" className="footer-link">Piscina de Prêmios PvE</a>
            </div>
          </div>

        </div>

        {/* Disclaimer Legal */}
        <div style={{
          borderTop: '1px solid var(--border-subtle)',
          paddingTop: '30px',
          display: 'flex',
          flexDirection: 'column',
          gap: '16px'
        }}>
          <p style={{ fontSize: '0.8rem', color: 'var(--text-dim)', lineHeight: 1.6 }}>
            <strong>Aviso de Jogo de Habilidade (Skill-Based Gaming):</strong> NUKE é uma plataforma de confrontos competitivos de tiro em primeira pessoa baseados 100% na pontaria, reflexos e habilidade tática do jogador. Não se trata de jogos de azar ou sorte pura (caça-níqueis ou roleta). As apostas são custodiadas por Smart Contracts descentralizados na rede Solana e liberadas com base na telemetria validada pelo servidor autoritativo. Jogue com responsabilidade. Proibido para menores de 18 anos.
          </p>

          <div style={{
            display: 'flex',
            flexWrap: 'wrap',
            justifyContent: 'space-between',
            alignItems: 'center',
            fontSize: '0.85rem',
            color: 'var(--text-dim)',
            paddingTop: '16px',
            borderTop: '1px solid rgba(255,255,255,0.03)'
          }}>
            <div>
              © 2026 NUKE TACTICAL FPS. Todos os direitos reservados.
            </div>
            <div style={{ display: 'flex', alignItems: 'center', gap: '6px' }}>
              Desenvolvido com Godot 4 WebGL & Solana Web3
            </div>
          </div>
        </div>

      </div>

      <style>{`
        .social-icon {
          width: 36px;
          height: 36px;
          border-radius: 8px;
          background: rgba(15, 20, 32, 0.8);
          border: 1px solid var(--border-subtle);
          display: flex;
          align-items: center;
          justify-content: center;
          color: #fff;
          text-decoration: none;
          transition: var(--transition);
        }
        .social-icon:hover {
          border-color: var(--cyan);
          background: rgba(0, 240, 255, 0.15);
          transform: translateY(-2px);
        }
        .footer-link {
          color: var(--text-muted);
          text-decoration: none;
          font-size: 0.9rem;
          transition: var(--transition);
        }
        .footer-link:hover {
          color: var(--cyan);
          transform: translateX(4px);
        }
      `}</style>
    </footer>
  );
}
