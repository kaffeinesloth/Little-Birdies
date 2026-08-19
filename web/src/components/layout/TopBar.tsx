import React from 'react';
import { Bell, Search, UserCircle } from 'lucide-react';

interface TopBarProps {
  title: string;
}

export const TopBar: React.FC<TopBarProps> = ({ title }) => {
  return (
    <header className="topbar glass">
      <h2 style={{ fontSize: '1.25rem', fontWeight: 600, margin: 0 }}>{title}</h2>
      
      <div style={{ marginLeft: 'auto', display: 'flex', alignItems: 'center', gap: '1.5rem' }}>
        <div style={{ position: 'relative' }}>
          <Search size={16} style={{ position: 'absolute', left: '10px', top: '50%', transform: 'translateY(-50%)', color: 'var(--color-text-muted)' }} />
          <input 
            type="text" 
            placeholder="Tìm kiếm..." 
            className="input"
            style={{ paddingLeft: '32px', width: '250px', backgroundColor: 'var(--color-surface-2)' }}
          />
        </div>
        
        <button style={{ color: 'var(--color-text-muted)' }}>
          <Bell size={20} />
        </button>
        
        <div style={{ display: 'flex', alignItems: 'center', gap: '0.5rem', paddingLeft: '1rem', borderLeft: '1px solid var(--color-border)' }}>
          <UserCircle size={28} style={{ color: 'var(--color-text-muted)' }} />
          <div style={{ display: 'flex', flexDirection: 'column' }}>
            <span style={{ fontSize: '0.85rem', fontWeight: 500 }}>Admin Demo</span>
            <span style={{ fontSize: '0.75rem', color: 'var(--color-text-muted)' }}>super_admin</span>
          </div>
        </div>
      </div>
    </header>
  );
};
