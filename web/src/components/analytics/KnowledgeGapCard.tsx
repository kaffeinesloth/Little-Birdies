import React from 'react';
import type { KnowledgeGap } from '../../types';
import { Lightbulb, FilePlus } from 'lucide-react';

export const KnowledgeGapCard: React.FC<{ items: KnowledgeGap[] }> = ({ items }) => {
  return (
    <div className="card" style={{ height: '100%', display: 'flex', flexDirection: 'column' }}>
      <div style={{ display: 'flex', alignItems: 'center', gap: '0.5rem', marginBottom: '1.5rem' }}>
        <Lightbulb size={18} style={{ color: 'var(--color-warning)' }} />
        <h3 style={{ margin: 0, fontSize: '1rem', color: 'var(--color-text)' }}>AI Knowledge Gaps</h3>
        <span style={{ marginLeft: 'auto', fontSize: '0.75rem', color: 'var(--color-text-muted)' }}>
          Chủ đề bot chưa biết
        </span>
      </div>
      
      <div style={{ display: 'flex', flexDirection: 'column', gap: '1rem', overflowY: 'auto' }}>
        {items.map((item, idx) => (
          <div key={idx} style={{ 
            display: 'flex', alignItems: 'center', justifyContent: 'space-between',
            paddingBottom: '1rem', borderBottom: '1px dashed var(--color-border)'
          }}>
            <div style={{ display: 'flex', flexDirection: 'column', gap: '0.25rem' }}>
              <span style={{ fontWeight: 500, fontSize: '0.95rem' }}>{item.topic}</span>
              <span style={{ fontSize: '0.8rem', color: 'var(--color-text-muted)' }}>
                {item.query_count} khách hàng đã hỏi
              </span>
            </div>
            <button className="btn btn-outline" style={{ padding: '0.4rem 0.75rem', fontSize: '0.8rem' }}>
              <FilePlus size={14} /> Thêm TL
            </button>
          </div>
        ))}
        {items.length === 0 && (
          <div style={{ textAlign: 'center', padding: '2rem 0', color: 'var(--color-text-muted)' }}>
            Bot đã bao phủ tốt các chủ đề hiện tại
          </div>
        )}
      </div>
    </div>
  );
};
