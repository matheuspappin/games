import React, { useState } from 'react';
import { Shield, Zap, Wallet, User, Play, ChevronRight } from 'lucide-react';

export default function Navbar({ onOpenLauncher, onOpenAuth, onOpenWallet, connectedWallet, walletAddress }) {
  const [mobileMenuOpen, setMobileMenuOpen] = useState(false);

  return (
    <nav style={{
      position: 'fixed',
      top: 0,
      left: 0,
      right: 0,
      zIndex: 900,
      background: 'rgba(7, 9, 14, 0.85)',
      backdropFilter: 'blur(16px)',
      borderBottom: '1px solid var(--border-subtle)',
      height: '76px',
      display: 'flex',
      alignItems: 'center'
    }}>
      <div className="container" style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
        
        {/* Brand Logo */}
        <a href="#" style={{ display: 'flex', alignItems: 'center', gap: '12px', textDecoration: 'none' }}>
          <div style={{
            width: '42px',
            height: '42px',
            borderRadius: '8px',
            background: 'linear-gradient(135deg, #00f0ff 0%, #ff5500 100%)',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            boxShadow: '0 0 20px rgba(0, 240, 255, 0.4)'
          }}>
            <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="#000" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round">
              <circle cx="12" cy="12" r="3"></circle>
              <path d="M12 3v3m0 12v3M3 12h3m12 0h3"></path>
              <path d="m5.6 5.6 2.1 2.1m8.6 8.6 2.1 2.1M5.6 18.4l2.1-2.1m8.6-8.6 2.1-2.1"></path>
            </svg>
          </div>
          <div>
            <div style={{ display: 'flex', alignItems: 'center', gap: '6px' }}>
              <span className="font-display" style={{ fontSize: '1.5rem', fontWeight: 900, color: '#fff', letterSpacing: '0.08em' }}>
                NUKE
              </span>
              <span style={{
                background: 'rgba(0, 240, 255, 0.15)',
                color: 'var(--cyan)',
                border: '1px solid var(--border-cyan)',
                padding: '2px 6px',
                borderRadius: '4px',
                fontSize: '0.65rem',
                fontWeight: 800,
                fontFamily: 'var(--font-tactical)'
              }}>
                SOLANA FPS
              </span>
            </div>
            <div style={{ fontSize: '0.7rem', color: 'var(--text-dim)', letterSpacing: '0.04em' }}>
              TACTICAL WEB3 SHOOTER
            </div>
          </div>
        </a>

        {/* Desktop Links */}
        <div style={{ display: 'none', md: 'flex', alignItems: 'center', gap: '28px' }} className="nav-links-desktop">
          <a href="#maps" className="nav-link">Mapas</a>
          <a href="#modes" className="nav-link">Modos de Jogo</a>
          <a href="#tokenomics" className="nav-link">Tokenomics ($NUKE)</a>
          <a href="#anticheat" className="nav-link">Anti-Cheat</a>
          <a href="#projections" className="nav-link">Economia</a>
        </div>

        {/* Action Buttons */}
        <div style={{ display: 'flex', alignItems: 'center', gap: '12px' }}>
          
          {/* Play Quick Button */}
          <button 
            onClick={onOpenLauncher}
            className="btn-primary" 
            style={{ padding: '10px 18px', fontSize: '0.85rem' }}
          >
            <Play size={15} fill="#030812" />
            <span>JOGAR ONLINE</span>
          </button>

          {/* User / Login Button */}
          <button 
            onClick={onOpenAuth}
            className="btn-secondary" 
            style={{ padding: '10px 14px', fontSize: '0.85rem' }}
            title="Login / Cadastro"
          >
            <User size={16} />
            <span style={{ display: 'none', sm: 'inline' }}>Entrar</span>
          </button>

          {/* Connect Wallet Button */}
          <button 
            onClick={onOpenWallet}
            className="btn-solana" 
            style={{ padding: '10px 16px', fontSize: '0.85rem' }}
          >
            <Wallet size={16} />
            <span>
              {connectedWallet 
                ? `${walletAddress.slice(0, 4)}...${walletAddress.slice(-4)}`
                : 'Conectar Phantom'}
            </span>
          </button>
        </div>

      </div>

      <style>{`
        .nav-link {
          color: var(--text-muted);
          text-decoration: none;
          font-family: var(--font-tactical);
          font-weight: 700;
          font-size: 0.95rem;
          letter-spacing: 0.05em;
          transition: var(--transition);
        }
        .nav-link:hover {
          color: var(--cyan);
          text-shadow: 0 0 12px var(--cyan-glow);
        }
        @media (min-width: 900px) {
          .nav-links-desktop { display: flex !important; }
        }
      `}</style>
    </nav>
  );
}
