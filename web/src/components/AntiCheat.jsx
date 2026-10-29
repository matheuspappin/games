import React from 'react';
import { ShieldCheck, EyeOff, Activity, Lock, Cpu, Server, Check } from 'lucide-react';

export default function AntiCheat() {
  const securityPillars = [
    {
      icon: Server,
      title: 'SERVIDOR AUTORITATIVO',
      badge: 'BLINDAGEM TOTAL',
      color: '#00f0ff',
      desc: 'O navegador do jogador nunca decide a física. Movimento, dano, vida e cooldowns de disparo existem única e exclusivamente na memória do servidor Linux (Godot Headless).',
      blocked: ['Speedhack & Teleporte', 'Godmode / Vida Infinita', 'Rapid Fire & No-Recoil']
    },
    {
      icon: EyeOff,
      title: 'ANTI-WALLHACK (FOG OF WAR)',
      badge: 'OCLUSÃO NO SERVIDOR',
      color: '#ff9900',
      desc: 'Se o oponente estiver atrás de uma parede de concreto no Nuketown e sem ruído de passos, o servidor NÃO transmite as coordenadas dele para o navegador. O Wallhack (ESP) fica cego.',
      blocked: ['Radares Externos', 'ESP Boxes no Navegador', 'Chams & Wireframe Hooks']
    },
    {
      icon: Activity,
      title: 'ANÁLISE BIOMÉTRICA DE AIMBOT',
      badge: 'INTELIGÊNCIA ESTATÍSTICA',
      color: '#14F195',
      desc: 'Algoritmos comparam a curva angular de aceleração do mouse com padrões humanos. Disparos instantâneos com tempos de reação desumanos (<120ms) denunciam gatilhos automatizados.',
      blocked: ['Triggerbots Automáticos', 'Aimbots de Travamento Linear', 'Snap-to-Head em 0ms']
    },
    {
      icon: Lock,
      title: 'RETENÇÃO FINANCEIRA DE SEGURANÇA',
      badge: 'SMART CONTRACT AUDIT',
      color: '#ffd700',
      desc: 'Antes da assinatura do Oráculo liberar o prêmio no Smart Contract, há uma janela de 2 minutos onde o replay da partida é verificado. Contas flagradas perdem a aposta.',
      blocked: ['Injeção de Pacotes Falsos', 'Rage Quit & Puxar Cabo', 'Reversão Maliciosa de Transação']
    }
  ];

  return (
    <section id="anticheat" style={{ padding: '100px 0', background: 'rgba(8, 11, 18, 0.7)', position: 'relative' }}>
      <div className="container">
        
        {/* Section Header */}
        <div className="section-header">
          <div className="section-tag">
            <ShieldCheck size={14} />
            <span>Integridade & Jogo Limpo</span>
          </div>
          <h2 className="section-title">
            ESCUDO ANTI-CHEAT DE <span className="gradient-text-cyan">ÚLTIMA GERAÇÃO</span>
          </h2>
          <p className="section-desc">
            Quando dinheiro real está em jogo, a segurança não pode falhar. Desenvolvemos uma arquitetura que não depende de permissões no Windows para neutralizar trapaças.
          </p>
        </div>

        {/* 4 Pillars Grid */}
        <div style={{
          display: 'grid',
          gridTemplateColumns: 'repeat(auto-fit, minmax(280px, 1fr))',
          gap: '24px',
          marginBottom: '50px'
        }}>
          {securityPillars.map((p, idx) => {
            const Icon = p.icon;
            return (
              <div 
                key={idx}
                className="glass-panel"
                style={{
                  padding: '30px 24px',
                  display: 'flex',
                  flexDirection: 'column',
                  justifyContent: 'space-between',
                  borderTop: `3px solid ${p.color}`
                }}
              >
                <div>
                  <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '16px' }}>
                    <div style={{
                      background: `${p.color}15`,
                      color: p.color,
                      padding: '10px',
                      borderRadius: '8px'
                    }}>
                      <Icon size={22} />
                    </div>
                    <span style={{
                      fontSize: '0.7rem',
                      fontFamily: 'var(--font-tactical)',
                      fontWeight: 800,
                      color: p.color,
                      background: 'rgba(255, 255, 255, 0.05)',
                      padding: '4px 8px',
                      borderRadius: '4px'
                    }}>
                      {p.badge}
                    </span>
                  </div>

                  <h3 className="font-display" style={{ fontSize: '1.25rem', fontWeight: 900, color: '#fff', marginBottom: '12px' }}>
                    {p.title}
                  </h3>

                  <p style={{ color: 'var(--text-muted)', fontSize: '0.9rem', lineHeight: 1.5, marginBottom: '20px' }}>
                    {p.desc}
                  </p>
                </div>

                <div style={{
                  background: 'rgba(5, 7, 12, 0.7)',
                  padding: '14px',
                  borderRadius: '6px',
                  border: '1px solid var(--border-subtle)'
                }}>
                  <div style={{ fontSize: '0.7rem', color: 'var(--text-dim)', fontFamily: 'var(--font-tactical)', fontWeight: 700, marginBottom: '8px' }}>
                    PROTEÇÃO CONTRA:
                  </div>
                  <div style={{ display: 'flex', flexDirection: 'column', gap: '6px' }}>
                    {p.blocked.map((item, i) => (
                      <div key={i} style={{ display: 'flex', alignItems: 'center', gap: '6px', fontSize: '0.8rem', color: '#fff' }}>
                        <Check size={14} color="var(--green)" />
                        <span>{item}</span>
                      </div>
                    ))}
                  </div>
                </div>

              </div>
            );
          })}
        </div>

        {/* Security Guarantee Banner */}
        <div style={{
          background: 'linear-gradient(135deg, rgba(0, 240, 255, 0.08) 0%, rgba(20, 241, 149, 0.08) 100%)',
          border: '1px solid var(--border-cyan)',
          borderRadius: 'var(--radius-md)',
          padding: '24px 32px',
          display: 'flex',
          flexWrap: 'wrap',
          alignItems: 'center',
          justifyContent: 'space-between',
          gap: '20px'
        }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: '16px' }}>
            <Cpu size={32} color="var(--cyan)" />
            <div>
              <div style={{ fontSize: '1.1rem', fontWeight: 800, color: '#fff' }}>
                Garantia de Fair Play & Oráculo Criptográfico
              </div>
              <div style={{ fontSize: '0.9rem', color: 'var(--text-muted)' }}>
                Todas as partidas são gravadas em tickrate de 60Hz com assinatura imutável do servidor.
              </div>
            </div>
          </div>

          <div style={{
            background: 'rgba(0, 255, 136, 0.15)',
            color: 'var(--green)',
            padding: '8px 16px',
            borderRadius: 'var(--radius-sm)',
            fontFamily: 'var(--font-tactical)',
            fontWeight: 800,
            fontSize: '0.85rem'
          }}>
            STATUS: 100% OPERACIONAL
          </div>
        </div>

      </div>
    </section>
  );
}
