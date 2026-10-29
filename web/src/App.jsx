import React, { useState } from 'react';
import Navbar from './components/Navbar';
import HeroCarousel from './components/HeroCarousel';
import LiveTicker from './components/LiveTicker';
import MapShowcase from './components/MapShowcase';
import GameModes from './components/GameModes';
import Tokenomics from './components/Tokenomics';
import AntiCheat from './components/AntiCheat';
import ProjectionsSection from './components/ProjectionsSection';
import Footer from './components/Footer';

import WalletModal from './components/WalletModal';
import AuthModal from './components/AuthModal';
import GameLauncherModal from './components/GameLauncherModal';

export default function App() {
  // Modals state
  const [isWalletOpen, setIsWalletOpen] = useState(false);
  const [isAuthOpen, setIsAuthOpen] = useState(false);
  const [isLauncherOpen, setIsLauncherOpen] = useState(false);

  // User state
  const [userGamertag, setUserGamertag] = useState('Operador_Alpha');
  const [connectedWallet, setConnectedWallet] = useState(false);
  const [walletAddress, setWalletAddress] = useState('8xNuke7d9mK2Lp4Va3a9f');
  const [balance, setBalance] = useState({ usdc: 250.00, nuke: 15400 });

  const handleConnectWallet = (walletName) => {
    setConnectedWallet(true);
    setWalletAddress('7xNk49B2mQ1LaZ9f3k8x');
    setIsWalletOpen(false);
  };

  const handleDisconnectWallet = () => {
    setConnectedWallet(false);
    setIsWalletOpen(false);
  };

  const handleLoginSuccess = (gamertag) => {
    setUserGamertag(gamertag);
  };

  return (
    <div style={{ minHeight: '100vh', display: 'flex', flexDirection: 'column' }}>
      
      {/* Top Fixed Navigation */}
      <Navbar 
        onOpenLauncher={() => setIsLauncherOpen(true)}
        onOpenAuth={() => setIsAuthOpen(true)}
        onOpenWallet={() => setIsWalletOpen(true)}
        connectedWallet={connectedWallet}
        walletAddress={walletAddress}
      />

      {/* Main Content */}
      <main style={{ flex: 1 }}>
        {/* Hero Section with Background Carousel */}
        <HeroCarousel 
          onOpenLauncher={() => setIsLauncherOpen(true)}
          onOpenWallet={() => setIsWalletOpen(true)}
        />

        {/* Real-time Simulated Statistics Ticker */}
        <LiveTicker />

        {/* Maps Section: Nuketown 2065 vs BO1 vs Hardhat */}
        <MapShowcase 
          onOpenLauncher={() => setIsLauncherOpen(true)}
        />

        {/* Game Modes: 1v1, 6v6, PvE Bots and High Roller */}
        <GameModes 
          onOpenLauncher={() => setIsLauncherOpen(true)}
        />

        {/* Tokenomics, pump.fun bonding curve & Wager Calculator */}
        <Tokenomics />

        {/* Server-Side Anti-Cheat & Fair Play Engine */}
        <AntiCheat />

        {/* 100 Players/Day Financial Viability Projections */}
        <ProjectionsSection />
      </main>

      {/* Footer */}
      <Footer />

      {/* Interactive Modals */}
      <WalletModal 
        isOpen={isWalletOpen}
        onClose={() => setIsWalletOpen(false)}
        onConnect={handleConnectWallet}
        onDisconnect={handleDisconnectWallet}
        connectedWallet={connectedWallet}
        walletAddress={walletAddress}
        balance={balance}
      />

      <AuthModal 
        isOpen={isAuthOpen}
        onClose={() => setIsAuthOpen(false)}
        onLoginSuccess={handleLoginSuccess}
      />

      <GameLauncherModal 
        isOpen={isLauncherOpen}
        onClose={() => setIsLauncherOpen(false)}
        userGamertag={userGamertag}
      />

    </div>
  );
}
