import React from 'react';
import { Swords, Users, Bot, Crown, Flame, Coins, Shield, ArrowUpRight } from 'lucide-react';

export default function GameModes({ onOpenLauncher }) {
  const modes = [
    {
      id: '1v1',
      title: 'DUELO 1v1 WAGER',
      tag: 'COMPETITIVO HARDCORE',
      badge: 'ALTA ADRENALINA',
      icon: Swords,
      color: '#00f0ff',
      payout: 'Vencedor Leva 94% do Pote',
      desc: 'O formato mais rápido e implacável. Dois jogadores entram no mapa, aposta mínima de $1 a $100 USDC ou $NUKE. Primeiro a alcançar 10 kills vence a aposta.',
      features: [
        'Sudden Death a 9x9 com tensão cardíaca extrema',
        'Exibição do HP restante do inimigo ao morrer (Near-Miss)',
        'Botão de Revanche instantânea: "Dobro ou Nada em 10s"'
      ],
      buyIn: 'De $1 a $100+ USDC'
    },
    {
      id: '6v6',
      title: 'TORNEIO 6v6 SIT & GO',
      tag: 'BATALHA EM EQUIPE',
      badge: '12 JOGADORES',
      icon: Users,
      color: '#ff9900',
      payout: 'Pote de $24 (com $2 de Buy-in)',
      desc: '12 jogadores se enfrentam no Nuketown. O time vencedor divide o pote, com a maior fatia reservada para o jogador MVP com mais abates (35% do prêmio).',
      features: [
        'Divisão por mérito: ninguém é carregado de graça',
        'Sistema de Bounties: abater o líder rende prêmio triplo',
        'Anti-Smurf: teto de rank para proteger novatos em mesas Recruta'
      ],
      buyIn: 'De $2 a $20 por jogador'
    },
    {
      id: 'pve-bots',
      title: 'PVE BOTS & LICENÇA',
      tag: 'PLAY-AND-EARN',
      badge: 'ESTILO BOMBCRYPTO',
      icon: Bot,
      color: '#14F195',
      payout: 'Recompensa por Headshots & Score',
      desc: 'Enfrente hordas de SoldierBots táticos. Compre sua arma/licença com $NUKE para liberar o direito de farmar tokens por abates de bots com durabilidade finita.',
      features: [
        'Durabilidade de arma: 10 partidas de recompensa por carga',
        'Mecanismo de queima: 50% dos tokens gastos na loja são queimados',
        'Piscina de recompensa diária fixa: imune a fazendas infinitas de bots'
      ],
      buyIn: 'Licença a partir de 500 $NUKE'
    },
    {
      id: 'high-roller',
      title: 'HIGH ROLLER VIP',
      tag: 'ARENA DE GRANDES APOSTAS',
      badge: 'COM TRANSMISSÃO AO VIVO',
      icon: Crown,
      color: '#ffd700',
      payout: 'Potes de $500 a $5.000+',
      desc: 'Mesas exclusivas para jogadores profissionais e criadores de conteúdo com plateia aberta de espectadores torcendo e assistindo em tempo real pelo navegador.',
      features: [
        'Chat aberto e plateia com apostas secundárias na torcida',
        'Tickrate VIP de 128Hz com latência ultra baixa',
        'Troféu de Prestígio e destaque no Leaderboard Semanal'
      ],
      buyIn: 'Acima de $500 USDC'
    }
  ];

  return (
    <section id="modes" style={{ padding: '100px 0', background: 'rgba(10, 14, 22, 0.5)', position: 'relative' }}>
      <div className="container">
        
        {/* Section Header */}
        <div className="section-header">
          <div className="section-tag">
            <Coins size={14} />
            <span>Formatos de Batalha & Wagers</span>
          </div>
          <h2 className="section-title">
            MODOS DE JOGO PROJETADOS PARA <span className="gradient-text-fire">MÁXIMA ADRENALINA</span>
          </h2>
          <p className="section-desc">
            Seja no duelo solitário 1v1, no caos tático do 6v6 em equipe ou no treino com bots monetizado, sua habilidade no mouse define seus ganhos.
          </p>
        </div>

        {/* Grid of Modes */}
        <div style={{
          display: 'grid',
          gridTemplateColumns: 'repeat(auto-fit, minmax(280px, 1fr))',
          gap: '24px'
        }}>
          {modes.map((mode) => {
            const Icon = mode.icon;
            return (
              <div 
                key={mode.id}
                className="glass-panel"
                style={{
                  padding: '32px 24px',
                  display: 'flex',
                  flexDirection: 'column',
                  justifyContent: 'space-between',
                  position: 'relative',
                  overflow: 'hidden'
                }}
              >
                {/* Glow accent bar at top */}
                <div style={{
                  position: 'absolute',
                  top: 0,
                  left: 0,
                  right: 0,
                  height: '3px',
                  background: mode.color,
                  boxShadow: `0 0 12px ${mode.color}`
                }} />

                <div>
                  {/* Top Badge */}
                  <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '18px' }}>
                    <div style={{
                      background: `rgba(255, 255, 255, 0.05)`,
                      border: `1px solid ${mode.color}40`,
                      color: mode.color,
                      padding: '4px 10px',
                      borderRadius: '4px',
                      fontSize: '0.75rem',
                      fontFamily: 'var(--font-tactical)',
                      fontWeight: 800
                    }}>
                      {mode.tag}
                    </div>

                    <div style={{
                      background: `${mode.color}15`,
                      color: mode.color,
                      padding: '8px',
                      borderRadius: '8px'
                    }}>
                      <Icon size={20} />
                    </div>
                  </div>

                  {/* Mode Title */}
                  <h3 className="font-display" style={{ fontSize: '1.4rem', fontWeight: 900, color: '#fff', marginBottom: '12px' }}>
                    {mode.title}
                  </h3>

                  {/* Description */}
                  <p style={{ color: 'var(--text-muted)', fontSize: '0.95rem', lineHeight: 1.5, marginBottom: '20px' }}>
                    {mode.desc}
                  </p>

                  {/* Payout highlight */}
                  <div style={{
                    background: 'rgba(7, 10, 16, 0.7)',
                    border: '1px solid var(--border-subtle)',
                    padding: '10px 14px',
                    borderRadius: '6px',
                    marginBottom: '20px'
                  }}>
                    <div style={{ fontSize: '0.7rem', color: 'var(--text-dim)', fontFamily: 'var(--font-tactical)', fontWeight: 700 }}>
                      ESTRUTURA DE PAGAMENTO
                    </div>
                    <div style={{ fontSize: '0.95rem', fontWeight: 800, color: mode.color }}>
                      {mode.payout}
                    </div>
                  </div>

                  {/* Features List */}
                  <div style={{ display: 'flex', flexDirection: 'column', gap: '8px', marginBottom: '26px' }}>
                    {mode.features.map((feat, i) => (
                      <div key={i} style={{ display: 'flex', alignItems: 'flex-start', gap: '8px', fontSize: '0.85rem', color: 'var(--text-main)' }}>
                        <span style={{ color: mode.color, fontWeight: 900 }}>•</span>
                        <span>{feat}</span>
                      </div>
                    ))}
                  </div>
                </div>

                {/* Bottom CTA */}
                <div>
                  <div style={{ fontSize: '0.75rem', color: 'var(--text-dim)', marginBottom: '8px', textAlign: 'center' }}>
                    Entrada: <strong style={{ color: '#fff' }}>{mode.buyIn}</strong>
                  </div>
                  <button
                    onClick={onOpenLauncher}
                    style={{
                      width: '100%',
                      padding: '12px',
                      background: 'rgba(255, 255, 255, 0.05)',
                      border: `1px solid ${mode.color}60`,
                      color: '#fff',
                      borderRadius: 'var(--radius-sm)',
                      fontFamily: 'var(--font-display)',
                      fontWeight: 700,
                      fontSize: '0.85rem',
                      cursor: 'pointer',
                      display: 'flex',
                      alignItems: 'center',
                      justifyContent: 'center',
                      gap: '8px',
                      transition: 'var(--transition)'
                    }}
                    onMouseEnter={(e) => {
                      e.currentTarget.style.background = mode.color;
                      e.currentTarget.style.color = '#000';
                    }}
                    onMouseLeave={(e) => {
                      e.currentTarget.style.background = 'rgba(255, 255, 255, 0.05)';
                      e.currentTarget.style.color = '#fff';
                    }}
                  >
                    <span>ENTRAR NA FILA</span>
                    <ArrowUpRight size={16} />
                  </button>
                </div>

              </div>
            );
          })}
        </div>

      </div>
    </section>
  );
}
