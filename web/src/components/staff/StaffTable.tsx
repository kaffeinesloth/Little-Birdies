import React from 'react';
import type { User, UserStatus } from '../../types';
import { StatusBadge } from './StatusBadge';
import { MoreVertical, Mail, Key } from 'lucide-react';

interface StaffTableProps {
  users: User[];
  onToggleStatus: (userId: string, currentStatus: UserStatus) => void;
  onDelete: (userId: string) => void;
}

export const StaffTable: React.FC<StaffTableProps> = ({ users, onToggleStatus, onDelete }) => {
  return (
    <div className="card" style={{ padding: 0, overflow: 'hidden' }}>
      <table style={{ width: '100%', borderCollapse: 'collapse', textAlign: 'left' }}>
        <thead style={{ backgroundColor: 'var(--color-surface-2)', borderBottom: '1px solid var(--color-border)' }}>
          <tr>
            <th style={{ padding: '1rem', fontWeight: 600, color: 'var(--color-text-muted)', fontSize: '0.85rem' }}>NHÂN VIÊN</th>
            <th style={{ padding: '1rem', fontWeight: 600, color: 'var(--color-text-muted)', fontSize: '0.85rem' }}>TRẠNG THÁI</th>
            <th style={{ padding: '1rem', fontWeight: 600, color: 'var(--color-text-muted)', fontSize: '0.85rem' }}>VAI TRÒ</th>
            <th style={{ padding: '1rem', fontWeight: 600, color: 'var(--color-text-muted)', fontSize: '0.85rem' }}>HOẠT ĐỘNG GẦN NHẤT</th>
            <th style={{ padding: '1rem', width: '50px' }}></th>
          </tr>
        </thead>
        <tbody>
          {users.map((user) => (
            <tr key={user.id} style={{ borderBottom: '1px solid var(--color-border)' }}>
              <td style={{ padding: '1rem' }}>
                <div style={{ display: 'flex', alignItems: 'center', gap: '0.75rem' }}>
                  <div style={{
                    width: '36px', height: '36px', borderRadius: '50%',
                    backgroundColor: 'var(--color-surface-2)', display: 'flex',
                    alignItems: 'center', justifyContent: 'center', fontWeight: 'bold'
                  }}>
                    {user.full_name.charAt(0)}
                  </div>
                  <div style={{ display: 'flex', flexDirection: 'column' }}>
                    <span style={{ fontWeight: 500 }}>{user.full_name}</span>
                    <span style={{ fontSize: '0.85rem', color: 'var(--color-text-muted)', display: 'flex', alignItems: 'center', gap: '4px' }}>
                      <Mail size={12} /> {user.email}
                    </span>
                  </div>
                </div>
              </td>
              <td style={{ padding: '1rem' }}>
                <button 
                  onClick={() => onToggleStatus(user.id, user.status)}
                  style={{ display: 'block', textAlign: 'left' }}
                  title="Click để đổi trạng thái"
                >
                  <StatusBadge status={user.status} />
                </button>
              </td>
              <td style={{ padding: '1rem' }}>
                <span style={{ 
                  fontSize: '0.8rem', padding: '4px 8px', borderRadius: '4px', 
                  backgroundColor: user.role === 'super_admin' ? 'rgba(210, 153, 34, 0.15)' : 'rgba(88, 166, 255, 0.15)',
                  color: user.role === 'super_admin' ? 'var(--color-warning)' : 'var(--color-accent)',
                  display: 'inline-flex', alignItems: 'center', gap: '4px'
                }}>
                  {user.role === 'super_admin' && <Key size={12} />}
                  {user.role === 'super_admin' ? 'Super Admin' : 'Agent'}
                </span>
              </td>
              <td style={{ padding: '1rem', fontSize: '0.9rem', color: 'var(--color-text-muted)' }}>
                {user.last_seen_at ? new Date(user.last_seen_at).toLocaleString('vi-VN') : 'Chưa hoạt động'}
              </td>
              <td style={{ padding: '1rem' }}>
                <button 
                  onClick={() => {
                    if(window.confirm('Bạn có chắc chắn muốn xóa nhân viên này?')) {
                      onDelete(user.id);
                    }
                  }}
                  style={{ color: 'var(--color-text-muted)', padding: '4px', borderRadius: '4px' }}
                  title="Xóa nhân viên"
                >
                  <MoreVertical size={18} />
                </button>
              </td>
            </tr>
          ))}
          
          {users.length === 0 && (
            <tr>
              <td colSpan={5} style={{ padding: '3rem', textAlign: 'center', color: 'var(--color-text-muted)' }}>
                Không có nhân viên nào
              </td>
            </tr>
          )}
        </tbody>
      </table>
    </div>
  );
};
