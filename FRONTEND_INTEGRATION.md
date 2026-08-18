# 📱 Hướng Dẫn Tích Hợp Frontend (Web & Mobile)
## Smart Helpdesk API & Realtime System

**Dành cho:** Đội ngũ phát triển Web Admin Dashboard (Next.js), Chat Widget, và Mobile App (Flutter).

---

## 1. Kết Nối Backend API

### Base URL
```
Backend API: http://localhost:8000/api/v1
```

### Cơ chế Authentication (JWT Bearer Token)
Tất cả request từ Admin Web / Mobile App đến FastAPI cần đính kèm JWT Access Token lấy từ Supabase Auth:

```typescript
// Ví dụ JavaScript / TypeScript (Web / Next.js)
import { createClient } from '@supabase/supabase-js'

const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY)

// 1. Đăng nhập qua Supabase Auth
const { data, error } = await supabase.auth.signInWithPassword({
  email: 'agent@shop.com',
  password: 'your_password'
})

const token = data.session?.access_token

// 2. Gọi FastAPI Backend với Token
const response = await fetch('http://localhost:8000/api/v1/tickets', {
  headers: {
    'Authorization': `Bearer ${token}`,
    'Content-Type': 'application/json'
  }
})
const result = await response.json()
console.log(result.data.items) // Danh sách tickets
```

---

## 2. Subscribe Realtime (Nhận tin nhắn & ticket mới live)

Hệ thống sử dụng **Supabase Realtime** để push dữ liệu trực tiếp về Frontend mà **không cần polling**.

### A. Web Admin / Mobile: Lắng nghe Ticket mới & Cập nhật Status
```typescript
// Lắng nghe mọi sự thay đổi trên bảng 'tickets'
supabase
  .channel('realtime-tickets')
  .on(
    'postgres_changes',
    { event: '*', schema: 'public', table: 'tickets' },
    (payload) => {
      console.log('Ticket thay đổi:', payload.eventType, payload.new)
      // Tự động load lại danh sách ticket hoặc cập nhật state UI
    }
  )
  .subscribe()
```

### B. Màn hình Chi tiết Chat: Lắng nghe Tin nhắn mới của Ticket
```typescript
// Subscribe tin nhắn mới thuộc về 1 ticket_id cụ thể
const ticketId = "f47ac10b-58cc-4372-a567-0e02b2c3d479"

supabase
  .channel(`ticket-messages:${ticketId}`)
  .on(
    'postgres_changes',
    {
      event: 'INSERT',
      schema: 'public',
      table: 'messages',
      filter: `ticket_id=eq.${ticketId}`
    },
    (payload) => {
      console.log('Tin nhắn mới vừa tới:', payload.new)
      // Thêm message mới vào khung chat
    }
  )
  .subscribe()
```

---

## 3. Tích Hợp Chat Widget (Khách hàng không cần đăng nhập)

Chat widget gửi tin nhắn qua public endpoint `POST /messages/incoming` và lắng nghe bot trả lời qua Realtime.

```typescript
// 1. Tạo hoặc lấy session_id của khách (lưu trong localStorage)
let customerId = localStorage.getItem('chat_session_id')
if (!customerId) {
  customerId = 'session_' + Math.random().toString(36).substring(2, 9)
  localStorage.setItem('chat_session_id', customerId)
}

// 2. Gửi tin nhắn khách lên Backend
async function sendMessageToShop(content: string) {
  const res = await fetch('http://localhost:8000/api/v1/messages/incoming', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      customer_id: customerId,
      customer_name: "Khách Vãng Lai",
      source: "web",
      content: content
    })
  })
  const json = await res.json()
  const ticketId = json.data.ticket_id

  // 3. Lắng nghe phản hồi từ AI Bot hoặc Nhân viên
  listenForReplies(ticketId)
}

function listenForReplies(ticketId: string) {
  supabase
    .channel(`widget:${ticketId}`)
    .on(
      'postgres_changes',
      {
        event: 'INSERT',
        schema: 'public',
        table: 'messages',
        filter: `ticket_id=eq.${ticketId}`
      },
      (payload) => {
        if (payload.new.sender_type !== 'customer') {
          console.log('Bot hoặc Agent reply:', payload.new.content)
          // Render tin nhắn của Bot/Agent lên bong bóng chat
        }
      }
    )
    .subscribe()
}
```

---

## 4. Mobile App (Flutter Integration Snippet)

```dart
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

final supabase = Supabase.instance.client;

// 1. Login
Future<String?> loginAgent(String email, String password) async {
  final res = await supabase.auth.signInWithPassword(email: email, password: password);
  final token = res.session?.accessToken;
  
  if (token != null) {
    // 2. Cập nhật FCM token cho Push Notification
    await updateFcmToken(token, "MY_DEVICE_FCM_TOKEN");
  }
  return token;
}

// 3. Fetch Tickets từ Backend
Future<List<dynamic>> fetchTickets(String token) async {
  final response = await http.get(
    Uri.parse('http://localhost:8000/api/v1/tickets'),
    headers: {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    },
  );
  final body = jsonDecode(response.body);
  return body['data']['items'];
}
```

---

## 5. Tóm Tắt Các API Cần Dùng Nhất

| Màn hình | Action | Method | Endpoint |
|---|---|---|---|
| Admin Dashboard | Xem chỉ số tổng quan | `GET` | `/tickets/stats/dashboard` |
| Danh sách Ticket | Lấy danh sách | `GET` | `/tickets?status=open&page=1` |
| Chi tiết Ticket | Xem tin nhắn & info | `GET` | `/tickets/{ticket_id}` |
| Chi tiết Ticket | Agent trả lời khách | `POST` | `/messages` |
| Chi tiết Ticket | Đóng Ticket (Resolved) | `PATCH` | `/tickets/{ticket_id}` `{ "status": "resolved" }` |
| Knowledge Base | Upload file PDF/DOCX | `POST` | `/documents` |
| Profile Agent | Bật/Tắt Online | `PATCH` | `/users/me/status` `{ "status": "online" }` |
