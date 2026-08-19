import React from 'react';
import { PieChart, Pie, Cell, Tooltip, ResponsiveContainer } from 'recharts';

interface BotReasonChartProps {
  aiPercent: number;
}

export const BotReasonChart: React.FC<BotReasonChartProps> = ({ aiPercent }) => {
  const data = [
    { name: 'AI tự xử lý', value: aiPercent },
    { name: 'Nhân viên xử lý', value: 100 - aiPercent }
  ];
  
  const COLORS = ['var(--color-accent)', 'var(--color-surface-2)'];

  return (
    <div className="card" style={{ height: '100%', display: 'flex', flexDirection: 'column' }}>
      <h3 style={{ margin: '0 0 1rem', fontSize: '1rem', color: 'var(--color-text-muted)' }}>Tỷ lệ AI xử lý</h3>
      <div style={{ flex: 1, position: 'relative', minHeight: '200px' }}>
        <ResponsiveContainer width="100%" height="100%">
          <PieChart>
            <Pie
              data={data}
              innerRadius={60}
              outerRadius={80}
              paddingAngle={5}
              dataKey="value"
              stroke="none"
            >
              {data.map((_, index) => (
                <Cell key={`cell-${index}`} fill={COLORS[index % COLORS.length]} />
              ))}
            </Pie>
            <Tooltip 
              contentStyle={{ backgroundColor: 'var(--color-surface)', borderColor: 'var(--color-border)', borderRadius: '8px' }}
              itemStyle={{ color: 'var(--color-text)' }}
              formatter={(value: number) => [`${value}%`, 'Tỷ lệ']}
            />
          </PieChart>
        </ResponsiveContainer>
        <div style={{ 
          position: 'absolute', top: '50%', left: '50%', transform: 'translate(-50%, -50%)', 
          textAlign: 'center' 
        }}>
          <div style={{ fontSize: '1.5rem', fontWeight: 700 }}>{aiPercent}%</div>
          <div style={{ fontSize: '0.75rem', color: 'var(--color-text-muted)' }}>Bởi AI Bot</div>
        </div>
      </div>
      <div style={{ display: 'flex', justifyContent: 'center', gap: '1.5rem', marginTop: '1rem' }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: '0.5rem', fontSize: '0.85rem' }}>
          <div style={{ width: '12px', height: '12px', borderRadius: '50%', backgroundColor: 'var(--color-accent)' }} />
          <span>AI Bot</span>
        </div>
        <div style={{ display: 'flex', alignItems: 'center', gap: '0.5rem', fontSize: '0.85rem' }}>
          <div style={{ width: '12px', height: '12px', borderRadius: '50%', backgroundColor: 'var(--color-surface-2)' }} />
          <span>Nhân viên</span>
        </div>
      </div>
    </div>
  );
};
