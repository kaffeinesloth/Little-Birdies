import React, { useState } from 'react';
import type { ProductIssue } from '../../types';
import { AlertOctagon, ChevronDown, ChevronRight } from 'lucide-react';

export const ProductIssueCard: React.FC<{ items: ProductIssue[] }> = ({ items }) => {
  const [expanded, setExpanded] = useState<string | null>(items[0]?.product || null);

  return (
    <div className="card" style={{ height: '100%', display: 'flex', flexDirection: 'column' }}>
      <div style={{ display: 'flex', alignItems: 'center', gap: '0.5rem', marginBottom: '1.5rem' }}>
        <AlertOctagon size={18} style={{ color: 'var(--color-danger)' }} />
        <h3 style={{ margin: 0, fontSize: '1rem', color: 'var(--color-text)' }}>Top sản phẩm bị báo lỗi</h3>
      </div>
      
      <div style={{ display: 'flex', flexDirection: 'column', gap: '0.75rem', overflowY: 'auto' }}>
        {items.map((item, idx) => {
          const isExpanded = expanded === item.product;
          return (
            <div key={item.product} style={{ 
              border: '1px solid var(--color-border)', 
              borderRadius: '8px',
              backgroundColor: isExpanded ? 'var(--color-surface-2)' : 'transparent',
              overflow: 'hidden'
            }}>
              <button 
                onClick={() => setExpanded(isExpanded ? null : item.product)}
                style={{ 
                  width: '100%', padding: '1rem', display: 'flex', alignItems: 'center', 
                  justifyContent: 'space-between', textAlign: 'left' 
                }}
              >
                <div style={{ display: 'flex', alignItems: 'center', gap: '0.75rem' }}>
                  <span style={{ 
                    width: '24px', height: '24px', display: 'flex', alignItems: 'center', justifyContent: 'center',
                    backgroundColor: idx === 0 ? 'rgba(248, 81, 73, 0.2)' : 'var(--color-surface)',
                    color: idx === 0 ? 'var(--color-danger)' : 'var(--color-text-muted)',
                    borderRadius: '50%', fontSize: '0.8rem', fontWeight: 'bold'
                  }}>
                    {idx + 1}
                  </span>
                  <span style={{ fontWeight: 500 }}>{item.product}</span>
                </div>
                <div style={{ display: 'flex', alignItems: 'center', gap: '1rem' }}>
                  <span style={{ 
                    padding: '2px 8px', borderRadius: '12px', fontSize: '0.75rem', fontWeight: 600,
                    backgroundColor: 'rgba(248, 81, 73, 0.1)', color: 'var(--color-danger)'
                  }}>
                    {item.complaint_count} reports
                  </span>
                  {isExpanded ? <ChevronDown size={16} /> : <ChevronRight size={16} />}
                </div>
              </button>
              
              {isExpanded && (
                <div style={{ padding: '0 1rem 1rem 3rem', fontSize: '0.85rem', color: 'var(--color-text-muted)' }}>
                  <ul style={{ margin: 0, paddingLeft: '1rem', display: 'flex', flexDirection: 'column', gap: '0.5rem' }}>
                    {item.top_issues.map((issue, i) => (
                      <li key={i}>{issue}</li>
                    ))}
                  </ul>
                </div>
              )}
            </div>
          );
        })}
        {items.length === 0 && (
          <div style={{ textAlign: 'center', padding: '2rem 0', color: 'var(--color-text-muted)' }}>
            Chưa có dữ liệu báo lỗi
          </div>
        )}
      </div>
    </div>
  );
};
