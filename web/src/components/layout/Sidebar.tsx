import React from 'react';
import { Users, BarChart3, Settings, HelpCircle } from 'lucide-react';

interface SidebarProps {
  activeTab: 'staff' | 'analytics';
  setActiveTab: (tab: 'staff' | 'analytics') => void;
}

export const Sidebar: React.FC<SidebarProps> = ({ activeTab, setActiveTab }) => {
  return (
    <aside className="sidebar glass">
      <div style={{ padding: '1.5rem', display: 'flex', alignItems: 'center', gap: '0.75rem', borderBottom: '1px solid var(--color-border)' }}>
        <div style={{ width: '32px', height: '32px', borderRadius: '8px', background: 'var(--color-accent)', display: 'flex', alignItems: 'center', justifyContent: 'center', fontWeight: 'bold', color: '#fff' }}>
          LB
        </div>
        <h1 style={{ fontSize: '1.1rem', fontWeight: 600, margin: 0 }}>Little Birdies</h1>
      </div>
      
      <nav style={{ padding: '1rem 0.75rem', display: 'flex', flexDirection: 'column', gap: '0.25rem', flex: 1 }}>
        <div style={{ fontSize: '0.75rem', textTransform: 'uppercase', color: 'var(--color-text-muted)', fontWeight: 600, margin: '0.5rem 0.5rem 0.25rem' }}>Management</div>
        
        <button
          onClick={() => setActiveTab('staff')}
          style={{
            display: 'flex', alignItems: 'center', gap: '0.75rem', padding: '0.5rem 0.75rem', borderRadius: '6px',
            backgroundColor: activeTab === 'staff' ? 'rgba(88, 166, 255, 0.1)' : 'transparent',
            color: activeTab === 'staff' ? 'var(--color-accent)' : 'var(--color-text)',
            textAlign: 'left'
          }}
        >
          <Users size={18} />
          <span>Nhân viên</span>
        </button>
        
        <button
          onClick={() => setActiveTab('analytics')}
          style={{
            display: 'flex', alignItems: 'center', gap: '0.75rem', padding: '0.5rem 0.75rem', borderRadius: '6px',
            backgroundColor: activeTab === 'analytics' ? 'rgba(88, 166, 255, 0.1)' : 'transparent',
            color: activeTab === 'analytics' ? 'var(--color-accent)' : 'var(--color-text)',
            textAlign: 'left'
          }}
        >
          <BarChart3 size={18} />
          <span>Lý do từ Bot</span>
        </button>
        
        <div style={{ fontSize: '0.75rem', textTransform: 'uppercase', color: 'var(--color-text-muted)', fontWeight: 600, margin: '1.5rem 0.5rem 0.25rem' }}>Settings</div>
        <button
          style={{
            display: 'flex', alignItems: 'center', gap: '0.75rem', padding: '0.5rem 0.75rem', borderRadius: '6px',
            color: 'var(--color-text-muted)', textAlign: 'left'
          }}
        >
          <Settings size={18} />
          <span>Cấu hình</span>
        </button>
      </nav>
      
      <div style={{ padding: '1rem', borderTop: '1px solid var(--color-border)' }}>
        <button style={{ display: 'flex', alignItems: 'center', gap: '0.5rem', color: 'var(--color-text-muted)', fontSize: '0.85rem' }}>
          <HelpCircle size={16} />
          <span>Trợ giúp & Hỗ trợ</span>
        </button>
      </div>
    </aside>
  );
};
