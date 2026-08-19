import React, { useEffect, useState } from 'react';
import { fetchDashboardStats, fetchProductIssues } from '../api/analytics';
import type { DashboardStats, ProductIssue, KnowledgeGap } from '../types';
import { BotReasonChart } from '../components/analytics/BotReasonChart';
import { ProductIssueCard } from '../components/analytics/ProductIssueCard';
import { KnowledgeGapCard } from '../components/analytics/KnowledgeGapCard';
import { MessageSquare, Clock, Zap, CheckCircle2 } from 'lucide-react';

export const AnalyticsPage: React.FC = () => {
  const [stats, setStats] = useState<DashboardStats | null>(null);
  const [productIssues, setProductIssues] = useState<ProductIssue[]>([]);
  const [gaps, setGaps] = useState<KnowledgeGap[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const loadData = async () => {
      try {
        const [statsData, issuesData] = await Promise.all([
          fetchDashboardStats(),
          fetchProductIssues()
        ]);
        setStats(statsData);
        setProductIssues(issuesData.top_product_issues);
        setGaps(issuesData.ai_knowledge_gaps);
      } catch (err: any) {
        console.error(err);
      } finally {
        setLoading(false);
      }
    };
    loadData();
  }, []);

  if (loading) return <div>Đang tải phân tích...</div>;
  if (!stats) return null;

  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: '2rem', maxWidth: '1200px', margin: '0 auto' }}>
      
      {/* Header */}
      <div>
        <h2 style={{ fontSize: '1.5rem', margin: '0 0 0.25rem' }}>Top lý do từ Bot</h2>
        <p style={{ margin: 0, color: 'var(--color-text-muted)' }}>Phân tích sâu về hiệu suất xử lý của AI và các vấn đề sản phẩm thường gặp.</p>
      </div>

      {/* KPI Cards */}
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(240px, 1fr))', gap: '1.5rem' }}>
        <div className="card" style={{ display: 'flex', alignItems: 'center', gap: '1rem' }}>
          <div style={{ width: '48px', height: '48px', borderRadius: '12px', backgroundColor: 'rgba(88, 166, 255, 0.1)', display: 'flex', alignItems: 'center', justifyContent: 'center', color: 'var(--color-accent)' }}>
            <MessageSquare size={24} />
          </div>
          <div>
            <div style={{ fontSize: '1.5rem', fontWeight: 700 }}>{stats.total_tickets}</div>
            <div style={{ fontSize: '0.85rem', color: 'var(--color-text-muted)' }}>Tổng ticket đã nhận</div>
          </div>
        </div>

        <div className="card" style={{ display: 'flex', alignItems: 'center', gap: '1rem' }}>
          <div style={{ width: '48px', height: '48px', borderRadius: '12px', backgroundColor: 'rgba(63, 185, 80, 0.1)', display: 'flex', alignItems: 'center', justifyContent: 'center', color: 'var(--color-accent-2)' }}>
            <Zap size={24} />
          </div>
          <div>
            <div style={{ fontSize: '1.5rem', fontWeight: 700 }}>{stats.ai_handled_percent}%</div>
            <div style={{ fontSize: '0.85rem', color: 'var(--color-text-muted)' }}>AI tự động xử lý</div>
          </div>
        </div>

        <div className="card" style={{ display: 'flex', alignItems: 'center', gap: '1rem' }}>
          <div style={{ width: '48px', height: '48px', borderRadius: '12px', backgroundColor: 'rgba(210, 153, 34, 0.1)', display: 'flex', alignItems: 'center', justifyContent: 'center', color: 'var(--color-warning)' }}>
            <Clock size={24} />
          </div>
          <div>
            <div style={{ fontSize: '1.5rem', fontWeight: 700 }}>{stats.avg_bot_response_seconds}s</div>
            <div style={{ fontSize: '0.85rem', color: 'var(--color-text-muted)' }}>Thời gian AI phản hồi</div>
          </div>
        </div>

        <div className="card" style={{ display: 'flex', alignItems: 'center', gap: '1rem' }}>
          <div style={{ width: '48px', height: '48px', borderRadius: '12px', backgroundColor: 'rgba(248, 81, 73, 0.1)', display: 'flex', alignItems: 'center', justifyContent: 'center', color: 'var(--color-danger)' }}>
            <CheckCircle2 size={24} />
          </div>
          <div>
            <div style={{ fontSize: '1.5rem', fontWeight: 700 }}>{stats.resolution_rate_percent}%</div>
            <div style={{ fontSize: '0.85rem', color: 'var(--color-text-muted)' }}>Tỷ lệ giải quyết xong</div>
          </div>
        </div>
      </div>

      {/* Main content grid */}
      <div style={{ display: 'grid', gridTemplateColumns: '1fr 2fr', gap: '1.5rem' }}>
        <BotReasonChart aiPercent={stats.ai_handled_percent} />
        <ProductIssueCard items={productIssues} />
      </div>

      <div style={{ display: 'grid', gridTemplateColumns: '2fr 1fr', gap: '1.5rem' }}>
        <div className="card">
          <h3 style={{ margin: '0 0 1rem', fontSize: '1rem', color: 'var(--color-text)' }}>Phân bổ khách liên hệ theo giờ</h3>
          <div style={{ display: 'flex', alignItems: 'flex-end', gap: '4px', height: '150px', marginTop: '2rem' }}>
            {stats.hourly_distribution.map((item, idx) => {
              const maxCount = Math.max(...stats.hourly_distribution.map(d => d.count));
              const height = (item.count / maxCount) * 100;
              return (
                <div key={idx} style={{ flex: 1, display: 'flex', flexDirection: 'column', alignItems: 'center', gap: '8px' }}>
                  <div style={{ 
                    width: '100%', 
                    height: `${height}%`, 
                    backgroundColor: 'var(--color-accent)', 
                    borderRadius: '4px 4px 0 0',
                    opacity: height > 70 ? 1 : 0.6
                  }} title={`${item.count} tickets lúc ${item.hour}`} />
                  <span style={{ fontSize: '0.7rem', color: 'var(--color-text-muted)', transform: 'rotate(-45deg)', transformOrigin: 'top left' }}>
                    {item.hour.split(':')[0]}h
                  </span>
                </div>
              );
            })}
          </div>
        </div>
        <KnowledgeGapCard items={gaps} />
      </div>
    </div>
  );
};
