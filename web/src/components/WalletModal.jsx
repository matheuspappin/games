import React, { useState } from 'react';
import { X, Wallet, Check, ExternalLink, ArrowDownLeft, ArrowUpRight, Copy } from 'lucide-react';

export default function WalletModal({ isOpen, onClose, onConnect, connectedWallet, walletAddress, balance, onDisconnect }) {
  const [copied, setCopied] = useState(false);

  if (!isOpen) return null;

  const wallets = [
    { name: 'Phantom', icon: '🟣', popular: true, desc: 'A carteira mais popular em Solana' },
    { name: 'Solflare', icon: '🟠', popular: false, desc: 'Suporte avançado para DeFi e Web3' },
    { name: 'Backpack', icon: '🎒', popular: false, desc: 'Carteira gamer de alto desempenho' },
    { name: 'Coinbase Wallet', icon: '🔵', popular: false, desc: 'Conexão via navegador móvel ou desktop' }
  ];

  const handleCopy = () => {
    navigator.clipboard.writeText(walletAddress);
    setCopied(true);
    setTimeout(() => setCopied(false), 2000);
  };

  return (
    <div className="modal-overlay" onClick={onClose}>
      <div className="modal-content" onClick={(e) => e.stopPropagation()} style={{ padding: '32px' }}>
        
        {/* Close Button */}
        <button 
          onClick={onClose}
          style={{
            position: 'absolute',
            top: '20px',
            right: '20px',
            background: 'none',
            border: 'none',
            color: 'var(--text-dim)',
            cursor: 'pointer'
          }}
        >
          <X size={20} />
        </button>

        {connectedWallet ? (
          /* WALLET CONNECTED VIEW */
          <div>
            <div style={{ display: 'flex', alignItems: 'center', gap: '12px', marginBottom: '24px' }}>
              <div style={{
                width: '48px',
                height: '48px',
                borderRadius: '12px',
                background: 'linear-gradient(135deg, #9945FF 0%, #14F195 100%)',
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'center',
                fontSize: '1.4rem'
              }}>
                🟣
              </div>
              <div>
                <span className="font-tactical" style={{ fontSize: '0.8rem', color: 'var(--green)', fontWeight: 800 }}>
                  CARTEIRA CONECTADA (SOLANA)
                </span>
                <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
                  <span className="font-display" style={{ fontSize: '1.1rem', color: '#fff', fontWeight: 800 }}>
                    {walletAddress.slice(0, 6)}...{walletAddress.slice(-4)}
                  </span>
                  <button onClick={handleCopy} style={{ background: 'none', border: 'none', color: 'var(--cyan)', cursor: 'pointer' }}>
                    {copied ? <Check size={14} color="var(--green)" /> : <Copy size={14} />}
                  </button>
                </div>
              </div>
            </div>

            {/* Balances Display */}
            <div style={{
              background: 'rgba(7, 10, 16, 0.8)',
              border: '1px solid var(--border-cyan)',
              borderRadius: 'var(--radius-sm)',
              padding: '20px',
              marginBottom: '24px'
            }}>
              <div style={{ fontSize: '0.75rem', color: 'var(--text-dim)', fontFamily: 'var(--font-tactical)', fontWeight: 700, marginBottom: '6px' }}>
                SALDO DISPONÍVEL PARA WAGERS
              </div>
              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '12px' }}>
                <span className="font-display" style={{ fontSize: '1.8rem', fontWeight: 900, color: '#fff' }}>
                  ${balance.usdc.toFixed(2)} USDC
                </span>
                <span style={{ background: 'rgba(0, 240, 255, 0.1)', color: 'var(--cyan)', padding: '4px 8px', borderRadius: '4px', fontSize: '0.75rem', fontWeight: 700 }}>
                  Stablecoin
                </span>
              </div>
              <div style={{ display: 'flex', justifyContent: 'space-between', borderTop: '1px solid var(--border-subtle)', paddingTop: '10px' }}>
                <span style={{ color: 'var(--text-muted)', fontSize: '0.9rem' }}>Tokens $NUKE:</span>
                <strong style={{ color: 'var(--gold)' }}>{balance.nuke.toLocaleString()} $NUKE</strong>
              </div>
            </div>

            {/* Actions: Deposit / Withdraw */}
            <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '12px', marginBottom: '24px' }}>
              <button className="btn-primary" style={{ padding: '12px', fontSize: '0.85rem' }}>
                <ArrowDownLeft size={16} />
                <span>DEPOSITAR</span>
              </button>
              <button className="btn-secondary" style={{ padding: '12px', fontSize: '0.85rem' }}>
                <ArrowUpRight size={16} />
                <span>SACAR SOL</span>
              </button>
            </div>

            <button 
              onClick={onDisconnect}
              style={{
                width: '100%',
                padding: '10px',
                background: 'rgba(255, 34, 85, 0.1)',
                border: '1px solid rgba(255, 34, 85, 0.3)',
                color: 'var(--red)',
                borderRadius: 'var(--radius-sm)',
                fontFamily: 'var(--font-tactical)',
                fontWeight: 700,
                fontSize: '0.85rem',
                cursor: 'pointer'
              }}
            >
              Desconectar Carteira
            </button>
          </div>
        ) : (
          /* WALLET CONNECT LIST VIEW */
          <div>
            <div style={{ textAlign: 'center', marginBottom: '28px' }}>
              <div style={{
                width: '56px',
                height: '56px',
                borderRadius: '16px',
                background: 'linear-gradient(135deg, #00f0ff 0%, #9945FF 100%)',
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'center',
                margin: '0 auto 16px auto',
                boxShadow: '0 0 24px rgba(0, 240, 255, 0.3)'
              }}>
                <Wallet size={26} color="#000" />
              </div>
              <h3 className="font-display" style={{ fontSize: '1.6rem', fontWeight: 900, color: '#fff', marginBottom: '6px' }}>
                CONECTAR CARTEIRA SOLANA
              </h3>
              <p style={{ color: 'var(--text-muted)', fontSize: '0.9rem' }}>
                Conecte para gerenciar seus saldos de apostas e receber payouts instantâneos.
              </p>
            </div>

            {/* Wallet Selection List */}
            <div style={{ display: 'flex', flexDirection: 'column', gap: '10px', marginBottom: '24px' }}>
              {wallets.map((w) => (
                <button
                  key={w.name}
                  onClick={() => onConnect(w.name)}
                  style={{
                    display: 'flex',
                    alignItems: 'center',
                    justifyContent: 'space-between',
                    padding: '14px 18px',
                    borderRadius: 'var(--radius-sm)',
                    background: 'rgba(15, 20, 32, 0.7)',
                    border: '1px solid var(--border-subtle)',
                    color: '#fff',
                    cursor: 'pointer',
                    transition: 'var(--transition)'
                  }}
                  onMouseEnter={(e) => {
                    e.currentTarget.style.borderColor = 'var(--cyan)';
                    e.currentTarget.style.background = 'rgba(0, 240, 255, 0.08)';
                  }}
                  onMouseLeave={(e) => {
                    e.currentTarget.style.borderColor = 'var(--border-subtle)';
                    e.currentTarget.style.background = 'rgba(15, 20, 32, 0.7)';
                  }}
                >
                  <div style={{ display: 'flex', alignItems: 'center', gap: '12px' }}>
                    <span style={{ fontSize: '1.4rem' }}>{w.icon}</span>
                    <div style={{ textAlign: 'left' }}>
                      <div style={{ fontWeight: 800, fontSize: '0.95rem' }}>{w.name}</div>
                      <div style={{ fontSize: '0.75rem', color: 'var(--text-dim)' }}>{w.desc}</div>
                    </div>
                  </div>
                  {w.popular && (
                    <span style={{
                      background: 'rgba(0, 240, 255, 0.15)',
                      color: 'var(--cyan)',
                      fontSize: '0.7rem',
                      fontFamily: 'var(--font-tactical)',
                      fontWeight: 800,
                      padding: '2px 8px',
                      borderRadius: '4px'
                    }}>
                      POPULAR
                    </span>
                  )}
                </button>
              ))}
            </div>

            <div style={{ fontSize: '0.75rem', color: 'var(--text-dim)', textAlign: 'center', lineHeight: 1.4 }}>
              Não possui carteira Solana? <a href="https://phantom.app" target="_blank" rel="noreferrer" style={{ color: 'var(--cyan)' }}>Baixe a Phantom aqui</a>.
            </div>
          </div>
        )}

      </div>
    </div>
  );
}
