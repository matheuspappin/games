import React from 'react';
import { DollarSign, TrendingUp, Server, ShieldCheck, CheckCircle2 } from 'lucide-react';

export default function ProjectionsSection() {
  return (
    <section id="projections" style={{ padding: '100px 0', position: 'relative' }}>
      <div className="container">
        
        {/* Section Header */}
        <div className="section-header">
          <div className="section-tag">
            <DollarSign size={14} />
            <span>Viabilidade & Tokenomics</span>
          </div>
          <h2 className="section-title">
            PROJEÇÃO FINANCEIRA COM <span className="gradient-text-cyan">100 JOGADORES / DIA</span>
          </h2>
          <p className="section-desc">
            Estudo econômico detalhado baseado no consumo médio de $20 dólares por jogador ativo (dividido entre licenças de treino com bots e volume girado em wagers 1v1/6v6).
          </p>
        </div>

        {/* 3 Metric Cards */}
        <div style={{
          display: 'grid',
          gridTemplateColumns: 'repeat(auto-fit, minmax(300px, 1fr))',
          gap: '24px',
          marginBottom: '40px'
        }}>
          <div className="glass-panel" style={{ padding: '30px' }}>
            <div style={{ fontSize: '0.8rem', color: 'var(--text-dim)', fontFamily: 'var(--font-tactical)', fontWeight: 700, marginBottom: '6px' }}>
              VOLUME BRUTO MOVIMENTADO
            </div>
            <div className="font-display" style={{ fontSize: '2.4rem', fontWeight: 900, color: '#fff', marginBottom: '8px' }}>
              $60.000 <span style={{ fontSize: '1.2rem', color: 'var(--text-muted)' }}>/mês</span>
            </div>
            <p style={{ fontSize: '0.9rem', color: 'var(--text-muted)' }}>
              100 jogadores ativos diariamente consumindo uma média de $20 dólares em compras de licenças e buy-ins de wagers.
            </p>
          </div>

          <div className="glass-panel" style={{ padding: '30px', border: '1px solid var(--cyan)', boxShadow: '0 0 30px rgba(0, 240, 255, 0.15)' }}>
            <div style={{ fontSize: '0.8rem', color: 'var(--cyan)', fontFamily: 'var(--font-tactical)', fontWeight: 700, marginBottom: '6px' }}>
              LUCRO LÍQUIDO DA PLATAFORMA
            </div>
            <div className="font-display" style={{ fontSize: '2.4rem', fontWeight: 900, color: 'var(--green)', marginBottom: '8px' }}>
              $19.500 <span style={{ fontSize: '1.2rem', color: 'var(--text-muted)' }}>/mês</span>
            </div>
            <p style={{ fontSize: '0.9rem', color: 'var(--text-muted)' }}>
              Equivalente a <strong>~R$ 97.500 reais mensais</strong> limpos no bolso (margem líquida retida de ~32.5% do volume bruto).
            </p>
          </div>

          <div className="glass-panel" style={{ padding: '30px' }}>
            <div style={{ fontSize: '0.8rem', color: 'var(--text-dim)', fontFamily: 'var(--font-tactical)', fontWeight: 700, marginBottom: '6px' }}>
              CUSTOS OPERACIONAIS DE SERVIDORES
            </div>
            <div className="font-display" style={{ fontSize: '2.4rem', fontWeight: 900, color: 'var(--orange)', marginBottom: '8px' }}>
              &lt; $150 <span style={{ fontSize: '1.2rem', color: 'var(--text-muted)' }}>/mês</span>
            </div>
            <p style={{ fontSize: '0.9rem', color: 'var(--text-muted)' }}>
              Servidor dedicado Hetzner/DigitalOcean + Vercel Web + taxas de rede Solana. Margem operacional superior a <strong>98%</strong>.
            </p>
          </div>
        </div>

        {/* Detailed Financial Breakdown Table */}
        <div className="glass-panel" style={{ padding: '36px', overflowX: 'auto' }}>
          <h3 className="font-display" style={{ fontSize: '1.3rem', fontWeight: 900, marginBottom: '20px', color: '#fff' }}>
            DISCRIMINAÇÃO DETALHADA POR FONTE DE RECEITA
          </h3>

          <table style={{ width: '100%', borderCollapse: 'collapse', textAlign: 'left' }}>
            <thead>
              <tr style={{ borderBottom: '1px solid var(--border-subtle)' }}>
                <th style={{ padding: '14px', color: 'var(--text-dim)', fontFamily: 'var(--font-tactical)', fontSize: '0.85rem' }}>FONTE</th>
                <th style={{ padding: '14px', color: 'var(--text-dim)', fontFamily: 'var(--font-tactical)', fontSize: '0.85rem' }}>MECÂNICA</th>
                <th style={{ padding: '14px', color: 'var(--text-dim)', fontFamily: 'var(--font-tactical)', fontSize: '0.85rem' }}>POR DIA</th>
                <th style={{ padding: '14px', color: 'var(--text-dim)', fontFamily: 'var(--font-tactical)', fontSize: '0.85rem' }}>POR MÊS (30D)</th>
                <th style={{ padding: '14px', color: 'var(--text-dim)', fontFamily: 'var(--font-tactical)', fontSize: '0.85rem' }}>EM REAIS (BRL)</th>
              </tr>
            </thead>
            <tbody>
              <tr style={{ borderBottom: '1px solid rgba(255,255,255,0.05)' }}>
                <td style={{ padding: '16px 14px', fontWeight: 700, color: '#fff' }}>Venda de Armas / Licenças PvE</td>
                <td style={{ padding: '16px 14px', color: 'var(--text-muted)', fontSize: '0.9rem' }}>50% margem líquida retida da tesouraria</td>
                <td style={{ padding: '16px 14px', fontWeight: 800, color: 'var(--cyan)' }}>$500 / dia</td>
                <td style={{ padding: '16px 14px', fontWeight: 800, color: 'var(--cyan)' }}>$15.000 / mês</td>
                <td style={{ padding: '16px 14px', color: '#fff' }}>R$ 75.000</td>
              </tr>
              <tr style={{ borderBottom: '1px solid rgba(255,255,255,0.05)' }}>
                <td style={{ padding: '16px 14px', fontWeight: 700, color: '#fff' }}>Rake em Apostas (1v1 & 6v6)</td>
                <td style={{ padding: '16px 14px', color: 'var(--text-muted)', fontSize: '0.9rem' }}>6% de taxa da casa sobre o volume em giro</td>
                <td style={{ padding: '16px 14px', fontWeight: 800, color: 'var(--orange)' }}>$120 / dia</td>
                <td style={{ padding: '16px 14px', fontWeight: 800, color: 'var(--orange)' }}>$3.600 / mês</td>
                <td style={{ padding: '16px 14px', color: '#fff' }}>R$ 18.000</td>
              </tr>
              <tr style={{ borderBottom: '1px solid rgba(255,255,255,0.05)' }}>
                <td style={{ padding: '16px 14px', fontWeight: 700, color: '#fff' }}>Taxas de Saque (Cash-out)</td>
                <td style={{ padding: '16px 14px', color: 'var(--text-muted)', fontSize: '0.9rem' }}>2.5% de taxa de saque para a Phantom Wallet</td>
                <td style={{ padding: '16px 14px', fontWeight: 800, color: 'var(--gold)' }}>$30 / dia</td>
                <td style={{ padding: '16px 14px', fontWeight: 800, color: 'var(--gold)' }}>$900 / mês</td>
                <td style={{ padding: '16px 14px', color: '#fff' }}>R$ 4.500</td>
              </tr>
              <tr style={{ background: 'rgba(0, 240, 255, 0.05)' }}>
                <td style={{ padding: '18px 14px', fontWeight: 900, color: 'var(--green)', fontSize: '1.05rem' }}>TOTAL CONSOLIDADO LÍQUIDO</td>
                <td style={{ padding: '18px 14px', color: 'var(--green)', fontWeight: 700, fontSize: '0.9rem' }}>Sem intermediários ou despesas ocultas</td>
                <td style={{ padding: '18px 14px', fontWeight: 900, color: 'var(--green)', fontSize: '1.2rem' }}>$650 / dia</td>
                <td style={{ padding: '18px 14px', fontWeight: 900, color: 'var(--green)', fontSize: '1.2rem' }}>$19.500 / mês</td>
                <td style={{ padding: '18px 14px', fontWeight: 900, color: 'var(--green)', fontSize: '1.2rem' }}>~ R$ 97.500 / mês</td>
              </tr>
            </tbody>
          </table>
        </div>

      </div>
    </section>
  );
}
