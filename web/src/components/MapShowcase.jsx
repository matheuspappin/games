import React, { useState } from 'react';
import { MapPin, Target, Users, Zap, Eye, CheckCircle2, Lock } from 'lucide-react';

const MAPS_DATA = [
  {
    id: 'nuketown-2065',
    name: 'NUKETOWN 2065',
    edition: 'BLACK OPS 3 FUTURISTA',
    era: 'Ano 2065',
    image: '/assets/nuketown_2065.jpg',
    badge: 'ARENA PRINCIPAL 1v1 & 6v6',
    comingSoon: false,
    desc: 'O ápice da velocidade tática. Construído com estética futurista inspirada em Black Ops 3, apresentando a Casa Azul (House 01) e a Casa Laranja (House 02) com tecnologia holográfica e o lendário ônibus central de levitação magnética.',
    specs: [
      { label: 'Tamanho do Mapa', value: 'Médio / Close-Quarters' },
      { label: 'Tempo Médio de Partida', value: '3 a 5 Minutos' },
      { label: 'Modos Suportados', value: '1v1 Duelo, 6v6 TDM, Bots PvE' },
      { label: 'Ponto Crítico', value: 'Ônibus Central & Janelas Superiores' }
    ],
    features: [
      'Duas casas espelhadas com sacadas táticas para fuzis de assalto',
      'Corredor lateral de flanqueamento rápido para emboscadas com faca e submetralhadora',
      'Iluminação futurista com visibilidade 100% limpa para mira de precisão'
    ]
  },
  {
    id: 'nuketown-bo1',
    name: 'NUKETOWN CLÁSSICO',
    edition: 'BLACK OPS 1 RETRO (1960)',
    era: 'Ano 1960',
    image: '/assets/nuketown_bo1.jpg',
    badge: 'ARENA NOSTALGIA VINTAGE',
    comingSoon: false,
    desc: 'Fiel réplica do campo de testes nucleares secreto no deserto de Nevada. A clássica casa amarela em estilo colonial contra a casa verde menta, o clássico ônibus escolar amarelo e o letreiro digital de boas-vindas com contagem regressiva.',
    specs: [
      { label: 'Tamanho do Mapa', value: 'Clássico 1:1 Black Ops 1' },
      { label: 'Tempo Médio de Partida', value: '4 a 6 Minutos' },
      { label: 'Modos Suportados', value: '1v1 Duelo Wager, 6v6 Clássico' },
      { label: 'Ponto Crítico', value: 'Caminhão de Mudança & Piquetes' }
    ],
    features: [
      'Ambiente nostálgico sob o pôr do sol dourado do deserto de Nevada',
      'Manequins interativos no jardim que reagem a tiros e impacto',
      'Linhas de visão abertas entre as portas das garagens'
    ]
  },
  {
    id: 'hardhat',
    name: 'HARDHAT ARENA',
    edition: 'MODERN WARFARE COMBAT',
    era: 'Em Breve',
    comingSoon: true,
    image: '/assets/fps_combat_ads.jpg',
    badge: '🔒 EM BREVE • FASE 2',
    desc: 'Canteiro de obras urbano projetado especificamente para confrontos rápidos de curta distância. Tubos de concreto estreitos, andaimes e contêineres industriais criam o cenário ideal para confrontos implacáveis com espingardas e pistolas.',
    specs: [
      { label: 'Tamanho do Mapa', value: 'Compacto / Labirinto' },
      { label: 'Tempo Médio de Partida', value: '2 a 4 Minutos' },
      { label: 'Modos Suportados', value: '1v1 High Stakes, Modo Pistolas' },
      { label: 'Status de Lançamento', value: 'EM BREVE (FASE 2)' }
    ],
    features: [
      'Labirinto de concreto perfeito para jogadas de audição de passos (sound whore)',
      'Sem linhas de longa distância: favorece reação rápida e reflexos',
      'Excelente para partidas rápidas com apostas relâmpago de $1 a $5'
    ]
  }
];

export default function MapShowcase({ onOpenLauncher }) {
  const [selectedMap, setSelectedMap] = useState(MAPS_DATA[0]);

  return (
    <section id="maps" style={{ padding: '100px 0', position: 'relative' }}>
      <div className="container">
        
        {/* Section Header */}
        <div className="section-header">
          <div className="section-tag">
            <MapPin size={14} />
            <span>Campos de Batalha Lendários</span>
          </div>
          <h2 className="section-title">
            MAPAS ICÔNICOS RECONSTRUÍDOS <span className="gradient-text-cyan">DO ZERO EM 3D</span>
          </h2>
          <p className="section-desc">
            Cada esquina, janela e linha de tiro foi milimetricamente desenhada para balanceamento competitivo e tiroteios de alta adrenalina no seu navegador.
          </p>
        </div>

        {/* Map Selection Tabs */}
        <div style={{
          display: 'flex',
          flexWrap: 'wrap',
          gap: '12px',
          justifyContent: 'center',
          marginBottom: '40px'
        }}>
          {MAPS_DATA.map((map) => {
            const isSelected = selectedMap.id === map.id;
            return (
              <button
                key={map.id}
                onClick={() => setSelectedMap(map)}
                style={{
                  display: 'flex',
                  alignItems: 'center',
                  gap: '10px',
                  padding: '12px 24px',
                  borderRadius: 'var(--radius-sm)',
                  background: isSelected 
                    ? (map.comingSoon ? 'rgba(255, 102, 0, 0.15)' : 'rgba(0, 240, 255, 0.15)') 
                    : 'rgba(15, 20, 32, 0.7)',
                  border: isSelected 
                    ? (map.comingSoon ? '1px solid var(--orange)' : '1px solid var(--cyan)') 
                    : '1px solid var(--border-subtle)',
                  color: isSelected ? '#fff' : 'var(--text-muted)',
                  fontFamily: 'var(--font-display)',
                  fontWeight: 700,
                  fontSize: '0.9rem',
                  cursor: 'pointer',
                  boxShadow: isSelected 
                    ? (map.comingSoon ? '0 0 20px rgba(255, 102, 0, 0.3)' : '0 0 20px rgba(0, 240, 255, 0.25)') 
                    : 'none',
                  transition: 'var(--transition)'
                }}
              >
                <Target size={16} color={isSelected ? (map.comingSoon ? 'var(--orange)' : 'var(--cyan)') : 'var(--text-dim)'} />
                <span>{map.name}</span>
                <span style={{
                  fontSize: '0.65rem',
                  padding: '2px 8px',
                  borderRadius: '4px',
                  background: map.comingSoon 
                    ? 'rgba(255, 102, 0, 0.2)' 
                    : (isSelected ? 'var(--cyan)' : 'rgba(255,255,255,0.1)'),
                  color: map.comingSoon 
                    ? 'var(--orange)' 
                    : (isSelected ? '#000' : 'inherit'),
                  border: map.comingSoon ? '1px solid rgba(255, 102, 0, 0.5)' : 'none',
                  fontWeight: 800,
                  letterSpacing: '0.04em'
                }}>
                  {map.comingSoon ? 'EM BREVE' : map.era}
                </span>
              </button>
            );
          })}
        </div>

        {/* Selected Map Card Showcase */}
        <div className="glass-panel" style={{
          display: 'grid',
          gridTemplateColumns: 'repeat(auto-fit, minmax(340px, 1fr))',
          gap: '36px',
          padding: '36px',
          alignItems: 'center'
        }}>
          
          {/* Map Image with Viewfinder Overlay */}
          <div style={{ position: 'relative', borderRadius: 'var(--radius-md)', overflow: 'hidden' }}>
            <img 
              src={selectedMap.image} 
              alt={selectedMap.name} 
              style={{
                width: '100%',
                height: '420px',
                objectFit: 'cover',
                borderRadius: 'var(--radius-md)',
                display: 'block',
                border: '1px solid var(--border-subtle)',
                filter: selectedMap.comingSoon ? 'grayscale(25%) contrast(1.05)' : 'none'
              }}
            />
            
            {/* Holographic Badge */}
            <div style={{
              position: 'absolute',
              top: '16px',
              left: '16px',
              background: selectedMap.comingSoon ? 'rgba(255, 102, 0, 0.25)' : 'rgba(7, 10, 16, 0.85)',
              border: selectedMap.comingSoon ? '1px solid var(--orange)' : '1px solid var(--border-cyan)',
              color: selectedMap.comingSoon ? 'var(--orange)' : 'var(--cyan)',
              padding: '6px 14px',
              borderRadius: 'var(--radius-sm)',
              fontFamily: 'var(--font-tactical)',
              fontWeight: 800,
              fontSize: '0.8rem',
              backdropFilter: 'blur(8px)',
              boxShadow: selectedMap.comingSoon ? '0 0 16px rgba(255, 102, 0, 0.4)' : 'none'
            }}>
              {selectedMap.badge}
            </div>

            {/* Quick Play overlay button */}
            <button
              disabled={selectedMap.comingSoon}
              onClick={selectedMap.comingSoon ? undefined : onOpenLauncher}
              style={{
                position: 'absolute',
                bottom: '16px',
                right: '16px',
                background: selectedMap.comingSoon ? 'rgba(25, 30, 42, 0.9)' : 'rgba(0, 240, 255, 0.9)',
                color: selectedMap.comingSoon ? 'var(--orange)' : '#000',
                border: selectedMap.comingSoon ? '1px solid rgba(255, 102, 0, 0.4)' : 'none',
                padding: '10px 18px',
                borderRadius: 'var(--radius-sm)',
                fontFamily: 'var(--font-display)',
                fontWeight: 800,
                fontSize: '0.85rem',
                cursor: selectedMap.comingSoon ? 'not-allowed' : 'pointer',
                display: 'flex',
                alignItems: 'center',
                gap: '8px',
                boxShadow: selectedMap.comingSoon ? 'none' : '0 0 20px rgba(0, 240, 255, 0.5)',
                backdropFilter: 'blur(8px)'
              }}
            >
              {selectedMap.comingSoon ? (
                <>
                  <Lock size={16} color="var(--orange)" />
                  <span>EM BREVE</span>
                </>
              ) : (
                <>
                  <Eye size={16} />
                  <span>TESTAR NESTE MAPA</span>
                </>
              )}
            </button>
          </div>

          {/* Map Information & Tactical Specs */}
          <div>
            <div className="font-tactical" style={{ 
              color: selectedMap.comingSoon ? 'var(--orange)' : 'var(--cyan)', 
              fontWeight: 700, 
              fontSize: '0.9rem', 
              marginBottom: '8px' 
            }}>
              {selectedMap.edition}
            </div>
            
            <h3 className="font-display" style={{ fontSize: '2.2rem', fontWeight: 900, marginBottom: '16px', color: '#fff' }}>
              {selectedMap.name}
            </h3>

            <p style={{ color: 'var(--text-muted)', lineHeight: 1.6, marginBottom: '24px', fontSize: '1.05rem' }}>
              {selectedMap.desc}
            </p>

            {/* Tactical Specs Grid */}
            <div style={{
              display: 'grid',
              gridTemplateColumns: 'repeat(2, 1fr)',
              gap: '14px',
              marginBottom: '26px'
            }}>
              {selectedMap.specs.map((spec, i) => (
                <div key={i} style={{
                  background: 'rgba(12, 16, 26, 0.6)',
                  border: '1px solid var(--border-subtle)',
                  padding: '12px 16px',
                  borderRadius: 'var(--radius-sm)'
                }}>
                  <div style={{ fontSize: '0.75rem', color: 'var(--text-dim)', fontFamily: 'var(--font-tactical)', fontWeight: 700 }}>
                    {spec.label}
                  </div>
                  <div style={{ 
                    fontSize: '0.95rem', 
                    fontWeight: 800, 
                    color: spec.label.includes('Status') ? 'var(--orange)' : '#fff', 
                    marginTop: '2px' 
                  }}>
                    {spec.value}
                  </div>
                </div>
              ))}
            </div>

            {/* Key Features Bullet Points */}
            <div style={{ display: 'flex', flexDirection: 'column', gap: '10px', marginBottom: '28px' }}>
              {selectedMap.features.map((feat, i) => (
                <div key={i} style={{ display: 'flex', alignItems: 'flex-start', gap: '10px' }}>
                  <CheckCircle2 size={18} color={selectedMap.comingSoon ? 'var(--orange)' : 'var(--cyan)'} style={{ flexShrink: 0, marginTop: '2px' }} />
                  <span style={{ fontSize: '0.95rem', color: 'var(--text-main)' }}>
                    {feat}
                  </span>
                </div>
              ))}
            </div>

            {/* CTA */}
            {selectedMap.comingSoon ? (
              <button 
                disabled
                style={{
                  width: '100%',
                  padding: '14px',
                  background: 'rgba(255, 102, 0, 0.1)',
                  border: '1px solid var(--orange)',
                  color: 'var(--orange)',
                  borderRadius: 'var(--radius-sm)',
                  fontFamily: 'var(--font-display)',
                  fontWeight: 800,
                  fontSize: '0.95rem',
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'center',
                  gap: '10px',
                  cursor: 'not-allowed',
                  boxShadow: '0 0 20px rgba(255, 102, 0, 0.2)'
                }}
              >
                <Lock size={18} color="var(--orange)" />
                <span>DISPONÍVEL EM BREVE (FASE 2)</span>
              </button>
            ) : (
              <button 
                onClick={onOpenLauncher}
                className="btn-primary" 
                style={{ width: '100%', padding: '14px' }}
              >
                <Zap size={18} fill="#000" />
                <span>CARREGAR PARTIDA EM {selectedMap.name}</span>
              </button>
            )}
          </div>

        </div>

      </div>
    </section>
  );
}
