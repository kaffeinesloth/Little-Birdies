import type { User, UserRole, UserStatus } from '../types';

const API_BASE = 'http://localhost:8000/api/v1/users';

export const fetchUsers = async (): Promise<User[]> => {
  const res = await fetch(`${API_BASE}/demo-list`);
  const json = await res.json();
  if (json.meta.code !== 200) throw new Error(json.meta.message);
  return json.data;
};

export const createUser = async (payload: { full_name: string; email: string; role: UserRole }): Promise<User> => {
  const res = await fetch(`${API_BASE}/demo-create`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(payload),
  });
  const json = await res.json();
  if (json.meta.code !== 201) throw new Error(json.meta.message);
  return json.data;
};

export const deleteUser = async (userId: string): Promise<void> => {
  const res = await fetch(`${API_BASE}/demo-delete/${userId}`, { method: 'DELETE' });
  const json = await res.json();
  if (json.meta.code !== 200) throw new Error(json.meta.message);
};

export const updateUserStatus = async (userId: string, status: UserStatus): Promise<void> => {
  const res = await fetch(`${API_BASE}/demo-status/${userId}`, {
    method: 'PATCH',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ status }),
  });
  const json = await res.json();
  if (json.meta.code !== 200) throw new Error(json.meta.message);
};
