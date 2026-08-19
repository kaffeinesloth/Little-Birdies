import type { DashboardStats, ProductIssue, KnowledgeGap } from '../types';

const API_BASE = 'http://localhost:8000/api/v1/tickets';

export const fetchDashboardStats = async (): Promise<DashboardStats> => {
  const [statsRes, agentRes] = await Promise.all([
    fetch(`${API_BASE}/demo-stats`),
    fetch(`${API_BASE}/demo-agent-performance`)
  ]);

  const statsJson = await statsRes.json();
  const agentJson = await agentRes.json();

  if (statsJson.meta.code !== 200) throw new Error(statsJson.meta.message);
  if (agentJson.meta.code !== 200) throw new Error(agentJson.meta.message);

  return {
    ...statsJson.data,
    avg_bot_response_seconds: agentJson.data.avg_bot_response_seconds,
    avg_human_response_seconds: agentJson.data.avg_human_response_seconds,
    resolution_rate_percent: agentJson.data.resolution_rate_percent,
    ai_vs_human_ratio: agentJson.data.ai_vs_human_ratio,
    hourly_distribution: agentJson.data.hourly_distribution,
  };
};

export const fetchProductIssues = async (): Promise<{ top_product_issues: ProductIssue[], ai_knowledge_gaps: KnowledgeGap[] }> => {
  const res = await fetch(`${API_BASE}/demo-product-issues`);
  const json = await res.json();
  if (json.meta.code !== 200) throw new Error(json.meta.message);
  return json.data;
};
