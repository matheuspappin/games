import React, { useState, useEffect } from 'react';
import { Play, Flame, ShieldAlert, Sparkles, ChevronLeft, ChevronRight, Zap } from 'lucide-react';

const SLIDES = [
  {
    id: 'nuketown-2065',
    tag: 'MAPA FUTURISTA • 2065',
    title: 'NUKETOWN 2065',
    subtitle: 'A REVOLUÇÃO DO COMBATE TÁTICO NO SEU NAVEGADOR',
    desc: 'Arquitetura cibernética, ônibus de levitação magnética e combate frenético de curta distância. O clássico reimaginado em gráficos 3D modernos e física competitiva sem lag.',
    image: '/assets/nuketown_2065.jpg',
    accent: '#00f0ff'
  },
  {
    id: 'nuketown-bo1',
    tag: 'NOSTALGIA BLACK OPS 1 • 1960',
    title: 'NUKETOWN CLÁSSICO',
    subtitle: 'O CAMPO DE TESTES NUCLEAR MAIS ICÔNICO DO MUNDO',
    desc: 'Casas amarela e verde pastel, ônibus escolar, piquete branco e famílias de manequins no deserto de Nevada. A balística pura de 2010 com a tecnologia de 2026.',
    image: '/assets/nuketown_bo1.jpg',
    accent: '#ff9900'
  },
  {
    id: 'gunplay-ads',
    tag: 'MIRA ÓPTICA • BALÍSTICA REAL',
    title: 'MIRA ADS & GUNPLAY',
    subtitle: 'RECOIL CONTROLADO, HITMARKERS & ÁUDIO CLÁSSICO',
    desc: 'AK-47, M9 Beretta, miras holográficas de precisão e animações de viewmodel em primeira pessoa. Cada tiro conta para definir quem leva o pote de apostas.',
    image: '/assets/fps_combat_ads.jpg',
    accent: '#ff2255'
  },
  {
    id: 'tournament-wager',
    tag: 'SOLANA NETWORK • PUMP.FUN',
    title: 'ARENA $NUKE WAGER',
    subtitle: 'DUELOS 1v1, TORNEIOS 6v6 E POTES DE APOSTAS',
    desc: 'Deposite $NUKE ou USDC, enfrente adversários de mira afiada e receba saques instantâneos diretamente na sua Phantom Wallet após a validação do servidor.',
    image: '/assets/nuke_tournament.jpg',
    accent: '#14F195'
  }
];

export default function HeroCarousel({ onOpenLauncher, onOpenWallet }) {
  const [currentIndex, setCurrentIndex] = useState(0);
  const [isPaused, setIsPaused] = useState(false);

  useEffect(() => {
    if (isPaused) return;
    const interval = setInterval(() => {
      setCurrentIndex((prev) => (prev + 1) % SLIDES.length);
    }, 6000);
    return () => clearInterval(interval);
  }, [isPaused]);

  const currentSlide = SLIDES[currentIndex];

  const nextSlide = () => setCurrentIndex((prev) => (prev + 1) % SLIDES.length);
  const prevSlide = () => setCurrentIndex((prev) => (prev - 1 + SLIDES.length) % SLIDES.length);

  return (
    <div 
      style={{
        position: 'relative',
        minHeight: '100vh',
        display: 'flex',
        alignItems: 'center',
        paddingTop: '90px',
        paddingBottom: '60px',
        overflow: 'hidden'
      }}
      onMouseEnter={() => setIsPaused(true)}
      onMouseLeave={() => setIsPaused(false)}
    >
      {/* Background Images with smooth fade transition */}
      {SLIDES.map((slide, idx) => (
        <div
          key={slide.id}
          style={{
            position: 'absolute',
            inset: 0,
            backgroundImage: `url(${slide.image})`,
            backgroundSize: 'cover',
            backgroundPosition: 'center',
            opacity: idx === currentIndex ? 1 : 0,
            transform: idx === currentIndex ? 'scale(1.03)' : 'scale(1)',
            transition: 'opacity 1.2s cubic-bezier(0.16, 1, 0.3, 1), transform 8s ease-out',
            zIndex: 1
          }}
        />
      ))}

      {/* Cyber Overlays (Vignette, Gradient, Carbon Scanline) */}
      <div style={{
        position: 'absolute',
        inset: 0,
        background: 'linear-gradient(180deg, rgba(7, 9, 14, 0.75) 0%, rgba(7, 9, 14, 0.85) 60%, rgba(7, 9, 14, 0.98) 100%)',
        zIndex: 2
      }} />
      <div style={{
        position: 'absolute',
        inset: 0,
        background: 'radial-gradient(circle at 20% 40%, rgba(0, 240, 255, 0.15) 0%, transparent 60%)',
        zIndex: 3
      }} />

      {/* Hero Content */}
      <div className="container" style={{ position: 'relative', zIndex: 10 }}>
        <div style={{ maxWidth: '820px' }}>
          
          {/* Badge Tag */}
          <div style={{ display: 'inline-flex', alignItems: 'center', gap: '8px', marginBottom: '20px' }}>
            <span style={{
              background: 'rgba(0, 240, 255, 0.15)',
              border: '1px solid var(--border-cyan)',
              color: 'var(--cyan)',
              padding: '6px 14px',
              borderRadius: '999px',
              fontFamily: 'var(--font-tactical)',
              fontWeight: 800,
              fontSize: '0.85rem',
              letterSpacing: '0.08em',
              display: 'flex',
              alignItems: 'center',
              gap: '6px'
            }}>
              <span className="pulse-dot" />
              {currentSlide.tag}
            </span>

            <span style={{
              background: 'rgba(255, 102, 0, 0.15)',
              border: '1px solid rgba(255, 102, 0, 0.3)',
              color: 'var(--orange)',
              padding: '6px 12px',
              borderRadius: '999px',
              fontFamily: 'var(--font-tactical)',
              fontWeight: 700,
              fontSize: '0.8rem'
            }}>
              SEM DOWNLOAD • 100% WEB
            </span>
          </div>

          {/* Main Title */}
          <h1 className="font-display" style={{
            fontSize: 'clamp(2.8rem, 6vw, 4.8rem)',
            fontWeight: 900,
            lineHeight: 1.05,
            marginBottom: '14px',
            color: '#fff',
            textShadow: '0 4px 30px rgba(0, 0, 0, 0.8)'
          }}>
            {currentSlide.title}
          </h1>

          {/* Subtitle */}
          <h2 className="font-tactical" style={{
            fontSize: 'clamp(1.2rem, 2.5vw, 1.8rem)',
            fontWeight: 700,
            color: 'var(--cyan)',
            letterSpacing: '0.06em',
            marginBottom: '20px',
            textShadow: '0 0 20px var(--cyan-glow)'
          }}>
            {currentSlide.subtitle}
          </h2>

          {/* Description */}
          <p style={{
            fontSize: '1.15rem',
            color: 'var(--text-muted)',
            lineHeight: 1.6,
            marginBottom: '36px',
            maxWidth: '680px'
          }}>
            {currentSlide.desc}
          </p>

          {/* Action Buttons */}
          <div style={{ display: 'flex', flexWrap: 'wrap', gap: '16px', marginBottom: '40px' }}>
            <button 
              onClick={onOpenLauncher}
              className="btn-primary" 
              style={{ padding: '16px 36px', fontSize: '1.05rem' }}
            >
              <Play size={20} fill="#030812" />
              <span>JOGAR NO NAVEGADOR</span>
            </button>

            <button 
              onClick={onOpenWallet}
              className="btn-secondary" 
              style={{ padding: '16px 30px', fontSize: '1rem' }}
            >
              <Zap size={18} color="var(--cyan)" />
              <span>LOBBY DE APOSTAS</span>
            </button>

            <a 
              href="https://pump.fun" 
              target="_blank" 
              rel="noreferrer"
              className="btn-solana" 
              style={{ padding: '16px 26px', fontSize: '0.95rem', textDecoration: 'none' }}
            >
              <Flame size={18} />
              <span>COMPRAR $NUKE (PUMP.FUN)</span>
            </a>
          </div>

          {/* Quick Metrics Bar */}
          <div style={{
            display: 'grid',
            gridTemplateColumns: 'repeat(auto-fit, minmax(140px, 1fr))',
            gap: '16px',
            maxWidth: '650px',
            padding: '16px 20px',
            background: 'rgba(10, 14, 22, 0.75)',
            border: '1px solid var(--border-subtle)',
            borderRadius: 'var(--radius-md)',
            backdropFilter: 'blur(10px)'
          }}>
            <div>
              <div style={{ fontSize: '0.75rem', color: 'var(--text-dim)', fontFamily: 'var(--font-tactical)', fontWeight: 700 }}>
                MOTOR DE JOGO
              </div>
              <div style={{ fontSize: '1.1rem', fontWeight: 800, color: '#fff' }}>
                Godot 4 WebGL
              </div>
            </div>
            <div>
              <div style={{ fontSize: '0.75rem', color: 'var(--text-dim)', fontFamily: 'var(--font-tactical)', fontWeight: 700 }}>
                TICKRATE SERVIDOR
              </div>
              <div style={{ fontSize: '1.1rem', fontWeight: 800, color: 'var(--green)' }}>
                60Hz Autoritativo
              </div>
            </div>
            <div>
              <div style={{ fontSize: '0.75rem', color: 'var(--text-dim)', fontFamily: 'var(--font-tactical)', fontWeight: 700 }}>
                SAQUES CRIPTO
              </div>
              <div style={{ fontSize: '1.1rem', fontWeight: 800, color: 'var(--cyan)' }}>
                Instantâneo (Solana)
              </div>
            </div>
            <div>
              <div style={{ fontSize: '0.75rem', color: 'var(--text-dim)', fontFamily: 'var(--font-tactical)', fontWeight: 700 }}>
                TAXA DA PLATAFORMA
              </div>
              <div style={{ fontSize: '1.1rem', fontWeight: 800, color: 'var(--gold)' }}>
                Apenas 6% Rake
              </div>
            </div>
          </div>

        </div>
      </div>

      {/* Carousel Navigation Arrows & Thumbnails Controls */}
      <div style={{
        position: 'absolute',
        bottom: '30px',
        right: '40px',
        zIndex: 20,
        display: 'none',
        md: 'flex',
        flexDirection: 'column',
        alignItems: 'flex-end',
        gap: '14px'
      }} className="carousel-controls">
        
        {/* Thumbnails row */}
        <div style={{ display: 'flex', gap: '8px' }}>
          {SLIDES.map((slide, idx) => (
            <button
              key={slide.id}
              onClick={() => setCurrentIndex(idx)}
              style={{
                width: '70px',
                height: '42px',
                borderRadius: '6px',
                border: idx === currentIndex ? '2px solid var(--cyan)' : '1px solid rgba(255, 255, 255, 0.2)',
                backgroundImage: `url(${slide.image})`,
                backgroundSize: 'cover',
                backgroundPosition: 'center',
                cursor: 'pointer',
                opacity: idx === currentIndex ? 1 : 0.6,
                transform: idx === currentIndex ? 'scale(1.05)' : 'scale(1)',
                transition: 'var(--transition)',
                boxShadow: idx === currentIndex ? '0 0 16px var(--cyan-glow)' : 'none'
              }}
              title={slide.title}
            />
          ))}
        </div>

        {/* Arrow Buttons & Slide Counter */}
        <div style={{ display: 'flex', alignItems: 'center', gap: '12px' }}>
          <span className="font-tactical" style={{ fontSize: '0.9rem', color: 'var(--text-dim)', fontWeight: 700 }}>
            0{currentIndex + 1} / 0{SLIDES.length}
          </span>
          <button 
            onClick={prevSlide}
            style={{
              background: 'rgba(15, 20, 32, 0.8)',
              border: '1px solid var(--border-subtle)',
              color: '#fff',
              width: '38px',
              height: '38px',
              borderRadius: '6px',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              cursor: 'pointer'
            }}
          >
            <ChevronLeft size={20} />
          </button>
          <button 
            onClick={nextSlide}
            style={{
              background: 'rgba(15, 20, 32, 0.8)',
              border: '1px solid var(--border-subtle)',
              color: '#fff',
              width: '38px',
              height: '38px',
              borderRadius: '6px',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              cursor: 'pointer'
            }}
          >
            <ChevronRight size={20} />
          </button>
        </div>

      </div>

      <style>{`
        @media (min-width: 900px) {
          .carousel-controls { display: flex !important; }
        }
      `}</style>
    </div>
  );
}
