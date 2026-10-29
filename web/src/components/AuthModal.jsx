import React, { useState } from 'react';
import { X, Mail, Lock, User, LogIn, ArrowRight } from 'lucide-react';

export default function AuthModal({ isOpen, onClose, onLoginSuccess }) {
  const [tab, setTab] = useState('login'); // 'login' | 'register'
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [username, setUsername] = useState('');

  if (!isOpen) return null;

  const handleSubmit = (e) => {
    e.preventDefault();
    onLoginSuccess(username || email.split('@')[0] || 'Operador_Nuke');
    onClose();
  };

  return (
    <div className="modal-overlay" onClick={onClose}>
      <div className="modal-content" onClick={(e) => e.stopPropagation()} style={{ padding: '36px' }}>
        
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

        {/* Header */}
        <div style={{ textAlign: 'center', marginBottom: '24px' }}>
          <div style={{
            width: '48px',
            height: '48px',
            borderRadius: '12px',
            background: 'linear-gradient(135deg, #00f0ff 0%, #0099ff 100%)',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            margin: '0 auto 12px auto'
          }}>
            <LogIn size={24} color="#000" />
          </div>
          <h3 className="font-display" style={{ fontSize: '1.6rem', fontWeight: 900, color: '#fff', marginBottom: '4px' }}>
            {tab === 'login' ? 'ENTRAR NA CONTA' : 'CRIAR CONTA OPERADOR'}
          </h3>
          <p style={{ color: 'var(--text-muted)', fontSize: '0.85rem' }}>
            Acesse seu perfil, histórico de abates e inventário de armas.
          </p>
        </div>

        {/* Tab switch */}
        <div style={{
          display: 'flex',
          background: 'rgba(10, 14, 22, 0.8)',
          borderRadius: '8px',
          padding: '4px',
          marginBottom: '24px'
        }}>
          <button
            onClick={() => setTab('login')}
            style={{
              flex: 1,
              padding: '10px',
              border: 'none',
              borderRadius: '6px',
              background: tab === 'login' ? 'rgba(0, 240, 255, 0.15)' : 'transparent',
              color: tab === 'login' ? '#fff' : 'var(--text-dim)',
              fontFamily: 'var(--font-tactical)',
              fontWeight: 800,
              cursor: 'pointer'
            }}
          >
            ENTRAR
          </button>
          <button
            onClick={() => setTab('register')}
            style={{
              flex: 1,
              padding: '10px',
              border: 'none',
              borderRadius: '6px',
              background: tab === 'register' ? 'rgba(0, 240, 255, 0.15)' : 'transparent',
              color: tab === 'register' ? '#fff' : 'var(--text-dim)',
              fontFamily: 'var(--font-tactical)',
              fontWeight: 800,
              cursor: 'pointer'
            }}
          >
            CRIAR CONTA
          </button>
        </div>

        {/* Form */}
        <form onSubmit={handleSubmit} style={{ display: 'flex', flexDirection: 'column', gap: '16px' }}>
          {tab === 'register' && (
            <div>
              <label style={{ display: 'block', fontSize: '0.75rem', color: 'var(--text-dim)', fontFamily: 'var(--font-tactical)', fontWeight: 700, marginBottom: '6px' }}>
                NOME DE OPERADOR (GAMERTAG)
              </label>
              <div style={{ position: 'relative' }}>
                <User size={16} color="var(--text-dim)" style={{ position: 'absolute', left: '14px', top: '14px' }} />
                <input 
                  type="text" 
                  placeholder="Ex: Ghost_Sniper" 
                  value={username}
                  onChange={(e) => setUsername(e.target.value)}
                  required
                  style={{
                    width: '100%',
                    padding: '12px 14px 12px 42px',
                    background: 'rgba(15, 20, 32, 0.8)',
                    border: '1px solid var(--border-subtle)',
                    borderRadius: 'var(--radius-sm)',
                    color: '#fff',
                    outline: 'none',
                    fontSize: '0.9rem'
                  }}
                />
              </div>
            </div>
          )}

          <div>
            <label style={{ display: 'block', fontSize: '0.75rem', color: 'var(--text-dim)', fontFamily: 'var(--font-tactical)', fontWeight: 700, marginBottom: '6px' }}>
              E-MAIL
            </label>
            <div style={{ position: 'relative' }}>
              <Mail size={16} color="var(--text-dim)" style={{ position: 'absolute', left: '14px', top: '14px' }} />
              <input 
                type="email" 
                placeholder="seuemail@exemplo.com" 
                value={email}
                onChange={(e) => setEmail(e.target.value)}
                required
                style={{
                  width: '100%',
                  padding: '12px 14px 12px 42px',
                  background: 'rgba(15, 20, 32, 0.8)',
                  border: '1px solid var(--border-subtle)',
                  borderRadius: 'var(--radius-sm)',
                  color: '#fff',
                  outline: 'none',
                  fontSize: '0.9rem'
                }}
              />
            </div>
          </div>

          <div>
            <label style={{ display: 'block', fontSize: '0.75rem', color: 'var(--text-dim)', fontFamily: 'var(--font-tactical)', fontWeight: 700, marginBottom: '6px' }}>
              SENHA DE ACESSO
            </label>
            <div style={{ position: 'relative' }}>
              <Lock size={16} color="var(--text-dim)" style={{ position: 'absolute', left: '14px', top: '14px' }} />
              <input 
                type="password" 
                placeholder="••••••••••••" 
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                required
                style={{
                  width: '100%',
                  padding: '12px 14px 12px 42px',
                  background: 'rgba(15, 20, 32, 0.8)',
                  border: '1px solid var(--border-subtle)',
                  borderRadius: 'var(--radius-sm)',
                  color: '#fff',
                  outline: 'none',
                  fontSize: '0.9rem'
                }}
              />
            </div>
          </div>

          <button 
            type="submit"
            className="btn-primary" 
            style={{ width: '100%', padding: '14px', marginTop: '8px' }}
          >
            <span>{tab === 'login' ? 'ENTRAR NO COMBATE' : 'CRIAR CONTA GRÁTIS'}</span>
            <ArrowRight size={16} />
          </button>
        </form>

        {/* Demo Fast Login */}
        <div style={{ marginTop: '20px', textAlign: 'center' }}>
          <button
            onClick={() => {
              onLoginSuccess('Operador_Alpha');
              onClose();
            }}
            style={{
              background: 'none',
              border: 'none',
              color: 'var(--cyan)',
              fontSize: '0.8rem',
              cursor: 'pointer',
              textDecoration: 'underline'
            }}
          >
            Modo Rápido: Entrar como Convidado Demo (Operador_Alpha)
          </button>
        </div>

      </div>
    </div>
  );
}
