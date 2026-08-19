import React, { useState } from 'react';
import type { UserRole } from '../../types';
import { X } from 'lucide-react';

interface StaffModalProps {
  onClose: () => void;
  onSubmit: (data: { full_name: string; email: string; role: UserRole }) => void;
}

export const StaffModal: React.FC<StaffModalProps> = ({ onClose, onSubmit }) => {
  const [fullName, setFullName] = useState('');
  const [email, setEmail] = useState('');
  const [role, setRole] = useState<UserRole>('agent');

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    if (!fullName || !email) return;
    onSubmit({ full_name: fullName, email, role });
  };

  return (
    <div style={{
      position: 'fixed', inset: 0, backgroundColor: 'rgba(0,0,0,0.6)',
      display: 'flex', alignItems: 'center', justifyContent: 'center', zIndex: 50,
      backdropFilter: 'blur(4px)'
    }}>
      <div className="card" style={{ width: '400px', padding: '1.5rem', backgroundColor: 'var(--color-surface-2)' }}>
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '1.5rem' }}>
          <h3 style={{ margin: 0, fontSize: '1.25rem' }}>Mời nhân viên mới</h3>
          <button onClick={onClose} style={{ color: 'var(--color-text-muted)' }}><X size={20} /></button>
        </div>

        <form onSubmit={handleSubmit} style={{ display: 'flex', flexDirection: 'column', gap: '1rem' }}>
          <div>
            <label style={{ display: 'block', marginBottom: '0.5rem', fontSize: '0.9rem', color: 'var(--color-text-muted)' }}>Họ và tên</label>
            <input 
              className="input" 
              type="text" 
              value={fullName} 
              onChange={e => setFullName(e.target.value)} 
              placeholder="VD: Nguyễn Văn A"
              required
            />
          </div>
          <div>
            <label style={{ display: 'block', marginBottom: '0.5rem', fontSize: '0.9rem', color: 'var(--color-text-muted)' }}>Email</label>
            <input 
              className="input" 
              type="email" 
              value={email} 
              onChange={e => setEmail(e.target.value)} 
              placeholder="VD: agent@sportgear.vn"
              required
            />
          </div>
          <div>
            <label style={{ display: 'block', marginBottom: '0.5rem', fontSize: '0.9rem', color: 'var(--color-text-muted)' }}>Vai trò</label>
            <select className="select" value={role} onChange={e => setRole(e.target.value as UserRole)}>
              <option value="agent">Agent (Nhân viên CSKH)</option>
              <option value="super_admin">Super Admin (Quản lý)</option>
            </select>
          </div>

          <div style={{ display: 'flex', justifyContent: 'flex-end', gap: '0.75rem', marginTop: '1rem' }}>
            <button type="button" className="btn btn-outline" onClick={onClose}>Hủy</button>
            <button type="submit" className="btn btn-primary">Gửi lời mời</button>
          </div>
        </form>
      </div>
    </div>
  );
};
