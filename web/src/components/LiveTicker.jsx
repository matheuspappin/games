import React from 'react';
import { Flame, TrendingUp, ShieldCheck, Users, Radio, Coins } from 'lucide-react';

export default function LiveTicker() {
  const tickerItems = [
    { label: '$NUKE PREÇO', value: '$0.0482 USD', change: '+52.4%', isPositive: true, icon: TrendingUp },
    { label: 'POTE ATIVO (WAGERS)', value: '$64,280 USDC', change: 'Ao Vivo', isPositive: true, icon: Coins },
    { label: 'JOGADORES EM BATALHA', value: '1,428 Online', change: '12 Salas 6v6', isPositive: true, icon: Users },
    { label: 'TOKENS QUEIMADOS', value: '12,850,000 $NUKE', change: 'Deflacionário', isPositive: true, icon: Flame },
    { label: 'SERVIDORES SP & VIRGINIA', value: '18ms Ping', change: 'Tickrate 60Hz', isPositive: true, icon: Radio },
    { label: 'ESCUDO ANTI-CHEAT', value: '100% Ativo', change: 'Zero Hacks', isPositive: true, icon: ShieldCheck }
  ];

  return (
    <div style={{
      background: 'rgba(9, 12, 19, 0.95)',
      borderTop: '1px solid var(--border-subtle)',
      borderBottom: '1px solid var(--border-subtle)',
      padding: '12px 0',
      overflow: 'hidden',
      position: 'relative',
      zIndex: 30
    }}>
      <div style={{
        display: 'flex',
        gap: '40px',
        animation: 'tickerScroll 35s linear infinite',
        whiteSpace: 'nowrap',
        width: 'max-content'
      }}>
        {[...tickerItems, ...tickerItems].map((item, idx) => {
          const Icon = item.icon;
          return (
            <div key={idx} style={{ display: 'inline-flex', alignItems: 'center', gap: '10px' }}>
              <div style={{
                background: 'rgba(0, 240, 255, 0.1)',
                padding: '6px',
                borderRadius: '6px',
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'center',
                color: 'var(--cyan)'
              }}>
                <Icon size={14} />
              </div>
              <span className="font-tactical" style={{ fontSize: '0.8rem', color: 'var(--text-dim)', fontWeight: 700 }}>
                {item.label}:
              </span>
              <span style={{ fontSize: '0.9rem', fontWeight: 800, color: '#fff' }}>
                {item.value}
              </span>
              <span style={{
                fontSize: '0.75rem',
                fontWeight: 700,
                color: item.isPositive ? 'var(--green)' : 'var(--red)',
                background: 'rgba(0, 255, 136, 0.1)',
                padding: '2px 6px',
                borderRadius: '4px'
              }}>
                {item.change}
              </span>
              <span style={{ color: 'rgba(255,255,255,0.15)', margin: '0 10px' }}>•</span>
            </div>
          );
        })}
      </div>

      <style>{`
        @keyframes tickerScroll {
          0% { transform: translateX(0); }
          100% { transform: translateX(-50%); }
        }
      `}</style>
    </div>
  );
}
