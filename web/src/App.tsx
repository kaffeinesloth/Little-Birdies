import { useState } from 'react';
import { Sidebar } from './components/layout/Sidebar';
import { TopBar } from './components/layout/TopBar';
import { StaffPage } from './pages/StaffPage';
import { AnalyticsPage } from './pages/AnalyticsPage';

function App() {
  const [activeTab, setActiveTab] = useState<'staff' | 'analytics'>('analytics');

  return (
    <div className="app-container">
      <Sidebar activeTab={activeTab} setActiveTab={setActiveTab} />
      
      <main className="main-content">
        <TopBar title={activeTab === 'staff' ? 'Quản Lý Nhân Viên' : 'Top Lý Do Từ Bot'} />
        
        <div className="page-content">
          {activeTab === 'staff' ? <StaffPage /> : <AnalyticsPage />}
        </div>
      </main>
    </div>
  );
}

export default App;
