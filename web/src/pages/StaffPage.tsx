import React, { useEffect, useState } from 'react';
import { StaffTable } from '../components/staff/StaffTable';
import { StaffModal } from '../components/staff/StaffModal';
import { fetchUsers, createUser, deleteUser, updateUserStatus } from '../api/users';
import type { User, UserRole, UserStatus } from '../types';
import { UserPlus } from 'lucide-react';

export const StaffPage: React.FC = () => {
  const [users, setUsers] = useState<User[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [showModal, setShowModal] = useState(false);

  useEffect(() => {
    loadUsers();
  }, []);

  const loadUsers = async () => {
    try {
      setLoading(true);
      const data = await fetchUsers();
      setUsers(data);
    } catch (err: any) {
      setError(err.message || 'Lỗi tải danh sách nhân viên');
    } finally {
      setLoading(false);
    }
  };

  const handleAddStaff = async (data: { full_name: string; email: string; role: UserRole }) => {
    try {
      await createUser(data);
      setShowModal(false);
      loadUsers();
      alert('Đã gửi lời mời thành công!');
    } catch (err: any) {
      alert(`Lỗi: ${err.message}`);
    }
  };

  const handleDelete = async (userId: string) => {
    try {
      await deleteUser(userId);
      loadUsers();
    } catch (err: any) {
      alert(`Lỗi: ${err.message}`);
    }
  };

  const handleToggleStatus = async (userId: string, currentStatus: UserStatus) => {
    // Demo cycle status: online -> offline -> disabled -> online
    let newStatus: UserStatus = 'online';
    if (currentStatus === 'online') newStatus = 'offline';
    else if (currentStatus === 'offline') newStatus = 'disabled';
    
    try {
      await updateUserStatus(userId, newStatus);
      loadUsers(); // Refresh local list
    } catch (err: any) {
      alert(`Lỗi: ${err.message}`);
    }
  };

  if (loading) return <div>Đang tải...</div>;
  if (error) return <div style={{ color: 'var(--color-danger)' }}>{error}</div>;

  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: '1.5rem', maxWidth: '1000px', margin: '0 auto' }}>
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
        <div>
          <h2 style={{ fontSize: '1.5rem', margin: '0 0 0.25rem' }}>Quản lý nhân viên</h2>
          <p style={{ margin: 0, color: 'var(--color-text-muted)' }}>Thêm, sửa và quản lý trạng thái của các agents hỗ trợ khách hàng.</p>
        </div>
        <button className="btn btn-primary" onClick={() => setShowModal(true)}>
          <UserPlus size={18} />
          Mời nhân viên
        </button>
      </div>

      <StaffTable 
        users={users} 
        onDelete={handleDelete}
        onToggleStatus={handleToggleStatus}
      />

      {showModal && (
        <StaffModal 
          onClose={() => setShowModal(false)}
          onSubmit={handleAddStaff}
        />
      )}
    </div>
  );
};
