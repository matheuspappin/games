import React, { useState } from 'react';
import { Flame, Coins, Calculator, TrendingUp, Sparkles, Shield, ExternalLink, Zap } from 'lucide-react';

export default function Tokenomics() {
  const [betAmount, setBetAmount] = useState(10);
  const [currency, setCurrency] = useState('USDC');

  const rakePercent = currency === '$NUKE' ? 0.03 : 0.06; // Desconto usando $NUKE!
  const totalPot = betAmount * 2;
  const houseFee = totalPot * rakePercent;
  const winnerPayout = totalPot - houseFee;
  const burnShare = houseFee * 0.5;

  return (
    <section id="tokenomics" style={{ padding: '100px 0', position: 'relative' }}>
      <div className="container">
        
        {/* Section Header */}
        <div className="section-header">
          <div className="section-tag">
            <Flame size={14} />
            <span>Solana SPL Token • pump.fun</span>
          </div>
          <h2 className="section-title">
            ECONOMIA DEFLACIONÁRIA DO TOKEN <span className="gradient-text-cyan">$NUKE</span>
          </h2>
          <p className="section-desc">
            Diferente de memecoins comuns sem produto, o $NUKE possui utilidade imediata em um FPS 3D com queima sistemática de suprimento a cada partida e compra de arma.
          </p>
        </div>

        {/* 2-Columns Grid: Token Info vs Interactive Calculator */}
        <div style={{
          display: 'grid',
          gridTemplateColumns: 'repeat(auto-fit, minmax(360px, 1fr))',
          gap: '36px',
          alignItems: 'stretch'
        }}>
          
          {/* Column 1: Token Specs & Bonding Curve */}
          <div className="glass-panel" style={{ padding: '36px' }}>
            <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: '20px' }}>
              <div>
                <span className="font-tactical" style={{ color: 'var(--cyan)', fontWeight: 700, fontSize: '0.85rem' }}>
                  REDE SOLANA • CONTRATO VERIFICADO
                </span>
                <h3 className="font-display" style={{ fontSize: '2rem', fontWeight: 900, color: '#fff' }}>
                  $NUKE (NUKETOWN)
                </h3>
              </div>
              <div style={{
                background: 'rgba(20, 241, 149, 0.1)',
                border: '1px solid rgba(20, 241, 149, 0.3)',
                color: '#14F195',
                padding: '8px 14px',
                borderRadius: '8px',
                fontFamily: 'var(--font-tactical)',
                fontWeight: 800,
                fontSize: '0.85rem'
              }}>
                PUMP.FUN LIVE
              </div>
            </div>

            {/* Bonding curve status box */}
            <div style={{
              background: 'rgba(7, 10, 16, 0.8)',
              border: '1px solid var(--border-cyan)',
              padding: '20px',
              borderRadius: 'var(--radius-sm)',
              marginBottom: '28px'
            }}>
              <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: '8px' }}>
                <span style={{ fontSize: '0.85rem', color: 'var(--text-muted)' }}>Progresso da Bonding Curve:</span>
                <span style={{ fontSize: '0.9rem', fontWeight: 800, color: 'var(--cyan)' }}>84% Concluído</span>
              </div>
              <div style={{
                width: '100%',
                height: '10px',
                background: 'rgba(255, 255, 255, 0.08)',
                borderRadius: '5px',
                overflow: 'hidden',
                position: 'relative',
                marginBottom: '10px'
              }}>
                <div style={{
                  width: '84%',
                  height: '100%',
                  background: 'linear-gradient(90deg, #00f0ff 0%, #14F195 100%)',
                  boxShadow: '0 0 12px var(--cyan)'
                }} />
              </div>
              <div style={{ fontSize: '0.75rem', color: 'var(--text-dim)' }}>
                Faltam ~12 SOL para a migração automática com liquidez travada para a <strong>Raydium DEX</strong>.
              </div>
            </div>

            {/* Token Utility Pillars */}
            <div style={{ display: 'flex', flexDirection: 'column', gap: '16px', marginBottom: '28px' }}>
              <div style={{ display: 'flex', gap: '14px', alignItems: 'flex-start' }}>
                <div style={{ background: 'rgba(255, 102, 0, 0.15)', color: 'var(--orange)', padding: '10px', borderRadius: '8px', flexShrink: 0 }}>
                  <Flame size={18} />
                </div>
                <div>
                  <h4 style={{ color: '#fff', fontSize: '1rem', fontWeight: 700, marginBottom: '2px' }}>
                    50% Queima Permanente em Armas
                  </h4>
                  <p style={{ color: 'var(--text-muted)', fontSize: '0.88rem', lineHeight: 1.4 }}>
                    Metade de todos os tokens gastos pelos jogadores para comprar armas ou recarregar durabilidade de bots são destruídos para sempre da blockchain.
                  </p>
                </div>
              </div>

              <div style={{ display: 'flex', gap: '14px', alignItems: 'flex-start' }}>
                <div style={{ background: 'rgba(0, 240, 255, 0.15)', color: 'var(--cyan)', padding: '10px', borderRadius: '8px', flexShrink: 0 }}>
                  <Zap size={18} />
                </div>
                <div>
                  <h4 style={{ color: '#fff', fontSize: '1rem', fontWeight: 700, marginBottom: '2px' }}>
                    Desconto de 50% no Rake de Apostas
                  </h4>
                  <p style={{ color: 'var(--text-muted)', fontSize: '0.88rem', lineHeight: 1.4 }}>
                    Jogadores que utilizam $NUKE para apostar em 1v1 ou 6v6 pagam apenas 3% de taxa da casa (contra 6% se usarem USDC/USDT).
                  </p>
                </div>
              </div>

              <div style={{ display: 'flex', gap: '14px', alignItems: 'flex-start' }}>
                <div style={{ background: 'rgba(255, 215, 0, 0.15)', color: 'var(--gold)', padding: '10px', borderRadius: '8px', flexShrink: 0 }}>
                  <Coins size={18} />
                </div>
                <div>
                  <h4 style={{ color: '#fff', fontSize: '1rem', fontWeight: 700, marginBottom: '2px' }}>
                    Piscina de Prêmios PvE Sustentável
                  </h4>
                  <p style={{ color: 'var(--text-muted)', fontSize: '0.88rem', lineHeight: 1.4 }}>
                    As recompensas de treino com bots são financiadas diretamente pelas taxas dos jogos PvP e vendas de armas, garantindo inflação zero.
                  </p>
                </div>
              </div>
            </div>

            <a 
              href="https://pump.fun" 
              target="_blank" 
              rel="noreferrer"
              className="btn-solana" 
              style={{ width: '100%', padding: '14px', textDecoration: 'none' }}
            >
              <ExternalLink size={16} />
              <span>VER GRÁFICO E COMPRAR NO PUMP.FUN</span>
            </a>
          </div>

          {/* Column 2: Interactive Wager Calculator */}
          <div className="glass-panel" style={{ padding: '36px', display: 'flex', flexDirection: 'column', justifyContent: 'space-between' }}>
            <div>
              <div style={{ display: 'flex', alignItems: 'center', gap: '10px', marginBottom: '8px' }}>
                <Calculator size={20} color="var(--gold)" />
                <span className="font-tactical" style={{ color: 'var(--gold)', fontWeight: 800, fontSize: '0.85rem' }}>
                  SIMULADOR DE GANHOS & RETORNO
                </span>
              </div>

              <h3 className="font-display" style={{ fontSize: '1.8rem', fontWeight: 900, color: '#fff', marginBottom: '14px' }}>
                CALCULADORA DE WAGER 1v1
              </h3>

              <p style={{ color: 'var(--text-muted)', fontSize: '0.95rem', marginBottom: '24px' }}>
                Simule quanto você ganha vencendo um duelo e como a taxa da casa alimenta a queima deflacionária do $NUKE.
              </p>

              {/* Currency Selector */}
              <div style={{ display: 'flex', gap: '10px', marginBottom: '24px' }}>
                {['USDC', '$NUKE'].map((curr) => (
                  <button
                    key={curr}
                    onClick={() => setCurrency(curr)}
                    style={{
                      flex: 1,
                      padding: '10px',
                      borderRadius: '6px',
                      background: currency === curr ? 'rgba(0, 240, 255, 0.2)' : 'rgba(10, 14, 22, 0.6)',
                      border: currency === curr ? '1px solid var(--cyan)' : '1px solid var(--border-subtle)',
                      color: currency === curr ? '#fff' : 'var(--text-dim)',
                      fontFamily: 'var(--font-display)',
                      fontWeight: 700,
                      cursor: 'pointer'
                    }}
                  >
                    {curr} {curr === '$NUKE' && '(Taxa 3%)'}
                  </button>
                ))}
              </div>

              {/* Bet Amount Slider */}
              <div style={{ marginBottom: '28px' }}>
                <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: '10px' }}>
                  <span style={{ fontSize: '0.9rem', color: 'var(--text-muted)' }}>Sua Aposta por Partida:</span>
                  <span className="font-display" style={{ fontSize: '1.4rem', fontWeight: 900, color: 'var(--cyan)' }}>
                    ${betAmount} {currency}
                  </span>
                </div>

                <input 
                  type="range" 
                  min="2" 
                  max="100" 
                  step="2"
                  value={betAmount}
                  onChange={(e) => setBetAmount(Number(e.target.value))}
                  style={{
                    width: '100%',
                    accentColor: 'var(--cyan)',
                    cursor: 'pointer'
                  }}
                />

                <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: '0.75rem', color: 'var(--text-dim)', marginTop: '6px' }}>
                  <span>$2 Min</span>
                  <span>$25</span>
                  <span>$50</span>
                  <span>$100 Max</span>
                </div>
              </div>

              {/* Results Breakdown Box */}
              <div style={{
                background: 'rgba(7, 10, 16, 0.8)',
                border: '1px solid var(--border-subtle)',
                borderRadius: '8px',
                padding: '20px',
                marginBottom: '24px'
              }}>
                <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: '10px' }}>
                  <span style={{ color: 'var(--text-muted)', fontSize: '0.9rem' }}>Pote Total em Disputa (2x):</span>
                  <strong style={{ color: '#fff' }}>${totalPot.toFixed(2)} {currency}</strong>
                </div>

                <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: '10px' }}>
                  <span style={{ color: 'var(--text-muted)', fontSize: '0.9rem' }}>Taxa da Casa ({rakePercent * 100}%):</span>
                  <span style={{ color: 'var(--text-dim)' }}>-${houseFee.toFixed(2)} {currency}</span>
                </div>

                <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: '14px' }}>
                  <span style={{ color: 'var(--orange)', fontSize: '0.9rem', display: 'flex', alignItems: 'center', gap: '4px' }}>
                    <Flame size={14} /> Queimado do $NUKE:
                  </span>
                  <strong style={{ color: 'var(--orange)' }}>${burnShare.toFixed(2)} {currency}</strong>
                </div>

                <div style={{
                  borderTop: '1px solid var(--border-subtle)',
                  paddingTop: '14px',
                  display: 'flex',
                  justifyContent: 'space-between',
                  alignItems: 'center'
                }}>
                  <span className="font-tactical" style={{ fontSize: '1rem', color: 'var(--green)', fontWeight: 800 }}>
                    VOCÊ RECEBE NA VITÓRIA:
                  </span>
                  <span className="font-display" style={{ fontSize: '1.6rem', color: 'var(--green)', fontWeight: 900 }}>
                    +${winnerPayout.toFixed(2)} {currency}
                  </span>
                </div>
              </div>
            </div>

            <div style={{ fontSize: '0.8rem', color: 'var(--text-dim)', textAlign: 'center', lineHeight: 1.4 }}>
              * Os saques são executados pelo Smart Contract em Solana logo após a validação da telemetria pelo servidor dedicado.
            </div>

          </div>

        </div>

      </div>
    </section>
  );
}
