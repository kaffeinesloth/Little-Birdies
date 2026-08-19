import React from 'react';
import type { UserStatus } from '../../types';

export const StatusBadge: React.FC<{ status: UserStatus }> = ({ status }) => {
  let color = '';
  let label = '';
  let dotColor = '';

  switch (status) {
    case 'online':
      color = 'rgba(63, 185, 80, 0.15)';
      label = 'Online';
      dotColor = 'var(--color-accent-2)';
      break;
    case 'offline':
      color = 'rgba(139, 148, 158, 0.15)';
      label = 'Offline';
      dotColor = 'var(--color-text-muted)';
      break;
    case 'disabled':
      color = 'rgba(248, 81, 73, 0.15)';
      label = 'Disabled';
      dotColor = 'var(--color-danger)';
      break;
  }

  return (
    <span style={{
      display: 'inline-flex',
      alignItems: 'center',
      gap: '6px',
      padding: '4px 10px',
      borderRadius: '20px',
      backgroundColor: color,
      color: dotColor,
      fontSize: '0.8rem',
      fontWeight: 500,
    }}>
      <span style={{
        width: '6px',
        height: '6px',
        borderRadius: '50%',
        backgroundColor: dotColor,
      }}></span>
      {label}
    </span>
  );
};
