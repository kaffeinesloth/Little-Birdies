# Smart Helpdesk - Hệ thống CSKH tự động bằng AI

Smart Helpdesk là nền tảng SaaS giúp các shop online vừa và nhỏ tự động hóa chăm sóc khách hàng bằng AI Agent, Retrieval-Augmented Generation (RAG), và quy trình quản lý ticket đơn giản. Hệ thống có thể tự động trả lời các câu hỏi lặp lại, phân loại ý định của khách hàng, và chuyển các khiếu nại khẩn cấp cho nhân viên thông qua ứng dụng mobile.

> Khẩu hiệu: "Tự động hóa CSKH. Xử lý khiếu nại tức thì."

## Thông tin nhóm

| # | Họ và tên | MSSV | Vai trò | Trách nhiệm chính |
| --- | --- | --- | --- | --- |
| 1 | Huỳnh Bá Anh Khoa | N22DCCN141 | Frontend Developer | Xây dựng frontend app và web, bao gồm Web Admin Dashboard, giao diện chat widget, trang demo chat, và giao diện responsive |
| 2 | Vũ Kim Long | N22DCCN050 | Backend Developer | Xây dựng REST API, database models, quy trình ticket, authentication, và tích hợp dịch vụ |
| 3 | Trần Tuấn Hải | N22DCCN026 | AI Engineer | Xây dựng RAG pipeline, intent classification, tạo câu trả lời bằng AI, và tích hợp LLM |
| 4 | Đặng Nhật Nam | N22DCDT038 | Frontend Support & Testing | Hỗ trợ phát triển frontend, kiểm thử luồng người dùng, hỗ trợ viết báo cáo, và kiểm tra yêu cầu chức năng |
| 5 | Tạ Quang An | N22DCAT003 | AI Engineer - Infrastructure | Setup ChromaDB/VectorDB, xây dựng Document Processor (PDF -> chunk -> embed), và FastAPI endpoints cho AI microservice |

## Tổng quan dự án

| Trường | Nội dung |
| --- | --- |
| Tên dự án | Smart Helpdesk - AI-Powered Customer Support System |
| Khẩu hiệu | "Tự động hóa CSKH. Xử lý khiếu nại tức thì." |
| Loại sản phẩm | SaaS Platform: Web + Mobile App + AI Agent |
| Lĩnh vực | Customer Service / SaaS |
| Người dùng mục tiêu | Chủ shop online vừa và nhỏ, người bán hàng thương mại điện tử, nhân viên CSKH |
| Công nghệ cốt lõi | LLM, RAG, LangChain, FastAPI, Supabase, Flutter |
| Mục tiêu chính | Giảm công việc CSKH lặp lại và tránh bỏ sót các tin nhắn khẩn cấp |
| Thời gian phát triển | 3 tuần |

## Trạng thái demo đã triển khai

Repository hiện là một monorepo Smart Helpdesk AI có thể chạy demo local:

- `services/api`: Backend FastAPI có health check, data access mock tương thích Supabase, auth/RBAC, API ticket/message, webhook Web/Facebook/Email, notification/presence, xử lý lỗi an toàn, CORS, và bảo vệ rate limit cho public endpoint.
- `services/ai`: AI microservice FastAPI có health check, fallback phân loại intent deterministic, xử lý tài liệu TXT/PDF/DOCX, RAG với ChromaDB, và fallback local khi chưa có LLM credential.
- `apps/web-admin`: Dashboard Next.js App Router có login/mock auth, navigation theo role, Unified Inbox, Knowledge Base upload UI, quản lý staff, Channel Settings, dashboard metrics, và widget demo.
- `apps/mobile`: Flutter app cho nhân viên CSKH có login/mock auth, navigation theo role, Inbox, Ticket Detail, Notifications, dashboard đơn giản cho admin, Settings/Profile, Online/Offline toggle, heartbeat, và mock push notification.
- `infra/supabase`: SQL migrations cho profile liên kết Supabase Auth, tickets, messages, documents, channels, notifications, enum, index, và ghi chú/policy RLS.
- `docs`: Tài liệu local demo, deployment, security, integrations, testing, và demo script.

Dự án có thể demo local mà không cần credential thật của Supabase, Facebook, Email, FCM, OpenAI, hoặc Gemini. Các tích hợp production được ghi rõ là boundary cần cấu hình bên ngoài.

## Chạy demo local nhanh

Chi tiết đầy đủ nằm trong [`docs/local-demo.md`](docs/local-demo.md). Tóm tắt:

1. Chạy AI service:

```sh
cd services/ai
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
APP_ENV=development RAG_CONFIDENCE_THRESHOLD=0.0 CHROMA_DB_PATH=./chroma uvicorn app.main:app --reload --host 127.0.0.1 --port 8001
```

2. Nạp file Knowledge Base mẫu:

```sh
curl -X POST http://127.0.0.1:8001/documents/process \
  -H "Content-Type: application/json" \
  -d '{"document_id":"demo-support-policy","file_url":"../../docs/demo-data/sample-support-policy.txt","file_type":"txt","file_name":"sample-support-policy.txt","file_size_bytes":856}'
```

3. Chạy API service:

```sh
cd services/api
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
APP_ENV=development LOCAL_MOCK_AUTH_ENABLED=true AI_SERVICE_URL=http://127.0.0.1:8001 uvicorn app.main:app --reload --host 127.0.0.1 --port 8000
```

4. Chạy Web Admin:

```sh
cd apps/web-admin
./node_modules/.bin/next dev --hostname 127.0.0.1 --port 3000
```

Mở `http://127.0.0.1:3000/login` và dùng:

- `owner@example.com` / `password` cho `super_admin`
- `agent@example.com` / `password` cho `agent`

5. Chạy Mobile nếu môi trường hỗ trợ:

```sh
cd apps/mobile
flutter run --dart-define=API_BASE_URL=http://127.0.0.1:8000
```

## Kịch bản demo cuối kỳ

Dùng [`docs/demo-script.md`](docs/demo-script.md) khi thuyết trình:

1. Bài toán kinh doanh.
2. Admin upload Knowledge Base.
3. Khách hàng hỏi FAQ trong widget.
4. AI trả lời tức thì bằng RAG.
5. Khách hàng gửi khiếu nại.
6. AI escalates sang ticket cho người thật.
7. Agent nhận ticket/thông báo.
8. Agent reply và resolve.
9. Dashboard cập nhật.

## Cảm hứng

Ý tưởng bắt đầu từ một trải nghiệm thực tế của một thành viên trong nhóm, người có dạy thêm một lớp thể thao ngoài giờ học.

Một ngày, có một học viên tiềm năng nhắn tin hỏi những thông tin rất cơ bản về lớp học: lớp còn nhận học viên mới không, lịch học như thế nào, và học phí bao nhiêu. Đây là những câu hỏi đơn giản, hoàn toàn có thể trả lời nhanh.

Tin nhắn đã được nhìn thấy, nhưng lúc đó thành viên đang dạy một lớp khác và không thể trả lời ngay. Sau buổi dạy, các công việc khác tiếp tục diễn ra và tin nhắn bị quên mất. Gần bốn tiếng sau, khi nhắn tin trả lời lại, khách hàng đã đăng ký một lớp khác.

Vấn đề không nằm ở độ khó của câu hỏi. Vấn đề nằm ở tốc độ phản hồi. Khách hàng chỉ cần một câu trả lời kịp thời, nhưng việc chậm trễ đã làm mất đi một cơ hội. Từ đó, nhóm muốn xây dựng một hệ thống có thể phản hồi ngay lập tức cho các câu hỏi cơ bản, đồng thời biết khi nào cần chuyển cho nhân viên thật xử lý.

## Xác định vấn đề

Từ trải nghiệm trên, nhóm nhận ra vấn đề này xảy ra phổ biến ở các doanh nghiệp online nhỏ:

- Các shop nhỏ thường chỉ có 1-2 người vừa bán hàng vừa chăm sóc khách hàng.
- Tin nhắn đến từ nhiều kênh như website chat, Facebook Messenger, và email.
- Nhiều câu hỏi của khách hàng bị lặp lại: giá cả, thời gian giao hàng, chính sách đổi trả, bảo hành, kích cỡ sản phẩm.
- Nhân viên dễ bỏ sót tin nhắn khi đang bận hoặc ngoài giờ làm việc.
- Khiếu nại và khách hàng đang bức xúc có thể không được nhận diện kịp thời.
- Phản hồi chậm có thể làm mất khách hàng và giảm uy tín doanh nghiệp.

## Giả thuyết giải pháp

Nếu có một hệ thống AI có thể trả lời câu hỏi thường gặp 24/7 và nhận biết khi nào cần nhân viên thật can thiệp, các doanh nghiệp nhỏ có thể giảm tải công việc CSKH, giảm áp lực nhân sự, và không bỏ sót những tin nhắn quan trọng.

## Giải pháp đề xuất

Smart Helpdesk kết hợp năm thành phần chính:

- AI Agent với RAG: Đọc tài liệu của doanh nghiệp như thông tin sản phẩm, chính sách đổi trả, bảo hành, và bảng giá để trả lời khách hàng chính xác.
- Intent Classification: Nhận diện tin nhắn là hỏi thông tin, khiếu nại, hoặc spam, sau đó chuyển các khiếu nại nghiêm trọng cho nhân viên.
- Omnichannel Unified Inbox: Gom tin nhắn từ website chat, Facebook Messenger, và email vào một hệ thống hỗ trợ duy nhất.
- Web Admin Dashboard: Cho phép chủ doanh nghiệp upload tài liệu, quản lý ticket, xem báo cáo, và quản lý nhân viên CSKH.
- Mobile App cho nhân viên: Gửi thông báo ticket khẩn cấp và cho phép nhân viên xử lý các ca khó mọi lúc mọi nơi.

## Hồ sơ khách hàng

**Phân khúc khách hàng:** Doanh nghiệp TMĐT vừa và nhỏ (SME), chủ shop online.

### Customer Jobs

- Đọc và trả lời tin nhắn của người mua hàng.
- Tra cứu thông tin sản phẩm, phí ship, và chính sách bảo hành.
- Sàng lọc và ưu tiên tin nhắn thủ công.

### Pains

- Quá tải tin nhắn, đặc biệt là vào ban đêm hoặc ngoài giờ hành chính, khiến khách phải chờ lâu và có thể hủy đơn.
- Tốn nhiều chi phí để thuê nhân sự trực page 24/7.
- Bỏ sót các tin nhắn khiếu nại nghiêm trọng, làm ảnh hưởng uy tín.
- Mệt mỏi và stress vì phải trả lời những câu hỏi y hệt nhau.

### Gains

- Giảm tải công việc cho nhân sự và tiết kiệm chi phí vận hành.
- Khách hàng được phản hồi nhanh nhất có thể.
- Can thiệp kịp thời khi khách hàng không hài lòng.
- Có dashboard để kiểm soát hiệu quả làm việc của nhân viên.

## Bản đồ giá trị

### Products and Services

- Website Admin: Nơi upload tài liệu, chính sách, và tri thức vận hành của cửa hàng.
- Mobile App: Ứng dụng điện thoại dành cho nhân viên CSKH để nhận thông báo tức thì.
- AI Agent với LLM và RAG: Đọc hiểu tài liệu đã upload, tự chat với khách, và tự động phân loại cảm xúc hoặc ý định tin nhắn.

### Pain Relievers

- AI Agent trực 24/7, tự động trả lời ngay các câu hỏi thường gặp.
- Tránh bỏ sót tin nhắn và xử lý khiếu nại nhanh chóng hơn.
- Giảm sự phụ thuộc vào con người cho các tác vụ lặp lại.

### Gain Creators

- Thời gian phản hồi nhanh hơn giúp cải thiện trải nghiệm khách hàng và cơ hội chuyển đổi.
- Unified Inbox giúp đội ngũ theo dõi hội thoại từ nhiều kênh tại một nơi.
- Dashboard thống kê giúp chủ shop nắm hiệu quả CSKH và tỷ lệ tự động hóa của AI.

## Tác động kỳ vọng

| Chỉ số | Trước Smart Helpdesk | Sau Smart Helpdesk |
| --- | --- | --- |
| Thời gian phản hồi trung bình | 15-30 phút ngoài giờ làm việc | Dưới 5 giây với câu hỏi AI xử lý được |
| Tỉ lệ tin nhắn AI xử lý | 0% | Khoảng 80% với câu hỏi lặp lại |
| Tỉ lệ bỏ sót khiếu nại | Khoảng 15% | Gần 0% nhờ push notification khẩn cấp |
| Nhân sự cần trực page | 2 người mỗi ca | 1 người, chỉ tập trung vào ca khó |

## Kiến trúc hệ thống

```text
INPUT LAYER
Web Chat Widget / Facebook Messenger / Email Webhook
        |
        | Tin nhắn và webhook
        v
ORCHESTRATOR LAYER
Nhận tin nhắn -> gắn source và sender_id -> lưu message -> đưa vào hàng đợi xử lý
        |
        v
AI CORE LAYER
Intent Classifier -> RAG Agent với ChromaDB -> LLM sinh câu trả lời
        |
        v
OUTPUT LAYER
Tự trả lời đúng kênh gốc HOẶC tạo ticket và thông báo nhân viên
        |
        +--> Web Admin có RBAC
        +--> Mobile App có FCM push notification
```

## Đặc tả hệ thống hiện tại

Đặc tả mới nhất định nghĩa Smart Helpdesk là hệ thống bốn lớp:

| Lớp | Trách nhiệm |
| --- | --- |
| Input Layer | Nhận tin nhắn từ Web Widget, Facebook Messenger webhook, và Email webhook. |
| Orchestrator Layer | Gắn `source` và `sender_id`, lưu message, và bắt đầu xử lý AI. |
| AI Core Layer | Phân loại intent, chạy RAG với ChromaDB, sinh câu trả lời, hoặc kích hoạt tạo ticket. |
| Output Layer | Trả lời đúng kênh gốc của khách, cập nhật Web Admin, và thông báo Mobile App. |

### Tác nhân

| Tác nhân | Vai trò |
| --- | --- |
| Khách hàng | Gửi tin nhắn qua Web Widget, Facebook Messenger, hoặc Email. |
| Super Admin | Chủ shop hoặc quản lý, có quyền Inbox, Dashboard, Knowledge Base, quản lý nhân viên, và cài đặt kênh. |
| Agent | Xử lý ticket được giao hoặc ticket đang mở và trả lời khách hàng. |
| AI Bot | Phân loại intent, trả lời bằng RAG, tạo ticket, và kích hoạt thông báo. |
| Hệ thống ngoài | Facebook Messenger API, Mailgun, hoặc SendGrid gửi webhook và nhận phản hồi outbound. |

### Bản đồ Use Case

| ID | Use Case | Tác nhân chính | Kết quả |
| --- | --- | --- | --- |
| UC01 | Gửi tin nhắn | Khách hàng / Hệ thống ngoài | Message được lưu với `source`, `sender_id`, và trạng thái xử lý. |
| UC02 | Nhận phản hồi từ AI | Khách hàng / AI Bot | Câu trả lời được gửi về Web, Facebook, hoặc Email và lưu với `sender_type = bot`. |
| UC03 | Chuyển giao nhân viên | Khách hàng / AI Bot / Agent | Ticket được tạo và hội thoại tiếp tục với nhân viên thật. |
| UC04 | Đăng nhập | Super Admin / Agent | Supabase Auth xác thực và hiển thị giao diện theo role. |
| UC05 | Xem Unified Inbox | Super Admin / Agent | Người dùng thấy ticket realtime theo quyền. |
| UC06 | Reply khách hàng | Super Admin / Agent | Reply của nhân viên được gửi qua kênh gốc và lưu với `sender_type = human`. |
| UC07 | Đóng ticket | Super Admin / Agent | Ticket chuyển `resolved`, lưu `resolved_at`, và gửi tin nhắn kết thúc. |
| UC08 | Upload tài liệu AI | Super Admin | File PDF, DOCX, hoặc TXT được upload, chunk, embed, và lưu vào ChromaDB. |
| UC09 | Xem dashboard | Super Admin | Admin thấy số tin nhắn, tỉ lệ AI xử lý, thời gian phản hồi, ticket mở, xu hướng, và top câu hỏi. |
| UC10 | Quản lý nhân viên | Super Admin | Tài khoản agent được tạo, mời, cập nhật, hoặc vô hiệu hóa. |
| UC11 | Cài đặt kênh | Super Admin | Thông tin Facebook và Email được lưu và kiểm tra kết nối. |
| UC12 | Nhận push notification | Agent / Super Admin | Nhân viên online nhận FCM notification cho ticket khẩn cấp. |
| UC13 | Bật/tắt Online | Agent | Trạng thái sẵn sàng được cập nhật và ảnh hưởng đến phân phối ticket. |
| UC14 | Phân loại intent | AI Bot | Message được gắn nhãn `question`, `complaint`, hoặc `spam`. |
| UC15 | Trả lời bằng RAG | AI Bot | Top-3 chunk liên quan được truy xuất và dùng để trả lời khách. |
| UC16 | Tạo ticket khẩn cấp | AI Bot | Khiếu nại hoặc câu hỏi AI không trả lời được trở thành ticket và thông báo nhân viên. |

### Luồng chính

1. Khách hàng gửi tin nhắn qua Web, Facebook, hoặc Email.
2. Orchestrator lưu message và gắn kênh nguồn.
3. AI phân loại message thành `question`, `complaint`, hoặc `spam`.
4. Nếu intent là `question`, RAG Agent tìm trong ChromaDB và trả lời khi có context phù hợp.
5. Nếu intent là `complaint` hoặc RAG không tìm được context đủ tốt, hệ thống gửi tin xoa dịu, tạo ticket, và thông báo agent online.
6. Nhân viên reply từ Web Admin hoặc Mobile App, và reply được route về đúng kênh gốc của khách.

## Phân quyền truy cập theo vai trò

Hệ thống dùng một hệ tài khoản duy nhất và một JWT token từ Supabase Auth. Sau khi đăng nhập, ứng dụng đọc trường `role` trong bảng `users` để hiển thị đúng giao diện Web hoặc Mobile.

| Tính năng | super_admin trên Web | agent trên Web | Mobile App, cả hai role |
| --- | :---: | :---: | :---: |
| Unified Inbox: xem và reply | Tất cả ticket | Ticket được giao/đang mở | Có |
| Push Notification | Browser notification | Browser notification | Tính năng chính |
| Lịch sử chat khách hàng | Có | Có | Có |
| Dashboard thống kê | Đầy đủ | Không | Bản đơn giản |
| Upload Knowledge Base | Có | Không | Không |
| Quản lý tài khoản nhân viên | Có | Không | Không |
| Cài đặt kênh: Facebook webhook và email | Có | Không | Không |

Quy tắc hiển thị theo role:

- `super_admin` xem được tất cả ticket.
- `agent` xem được ticket được giao cho mình và ticket đang mở có thể xử lý.
- Tài khoản bị vô hiệu hóa không thể đăng nhập, nhưng lịch sử chat vẫn được giữ lại.
- Agent online nhận push notification khẩn cấp; agent offline giữ các ticket đang xử lý nhưng không nhận ticket khẩn cấp mới.

## Các module chính

### 1. Chat Widget

Chat widget được khách hàng sử dụng trên website của doanh nghiệp.

- Nhúng vào bất kỳ website nào bằng một thẻ `<script>`.
- Hiển thị khung chat ở góc dưới bên phải website.
- Gửi và nhận tin nhắn text theo thời gian thực.
- Hiển thị typing indicator khi AI đang xử lý.
- Hỗ trợ chuyển giao từ AI sang nhân viên thật mà không reset đoạn chat.
- Hiển thị badge nguồn kênh Web, Facebook, hoặc Email.
- Nhận phản hồi Web qua Supabase Realtime.

### 2. Web Admin Dashboard: super_admin

Admin dashboard đầy đủ được sử dụng bởi chủ shop và quản lý.

- Đăng nhập bằng email/password qua Supabase Auth.
- Xem và reply tất cả tin nhắn từ Web, Facebook, và Email trong Unified Inbox.
- Lọc Inbox theo kênh và trạng thái ticket: Open, In Progress, Resolved.
- Upload file PDF, DOCX, hoặc TXT tối đa 10 MB để tạo knowledge base cho AI.
- Xem thống kê dashboard như số tin nhắn hôm nay, tỉ lệ AI tự xử lý, thời gian phản hồi trung bình, ticket đang mở, biểu đồ 7 ngày, và top câu hỏi.
- Quản lý tài khoản nhân viên CSKH.
- Cấu hình Facebook webhook và địa chỉ email nhận tin.

### 3. Web Admin Dashboard: agent

Dashboard Web giới hạn được sử dụng bởi nhân viên CSKH làm việc trên máy tính.

- Đăng nhập bằng tài khoản do super_admin tạo.
- Xem và reply ticket được giao hoặc đang mở.
- Xem toàn bộ lịch sử chat của khách hàng trong context viewer.
- Cập nhật trạng thái ticket thành In Progress hoặc Resolved.
- Không hiển thị Dashboard, Knowledge Base, quản lý nhân sự, và cài đặt kênh.

### 4. Mobile App

Mobile app được sử dụng bởi nhân viên CSKH.

- Đăng nhập bằng cùng tài khoản Supabase Auth với Web.
- Bật/tắt trạng thái Online/Offline.
- Nhận push notification khi có ticket mới hoặc tin nhắn khẩn cấp.
- Xem và reply tin nhắn realtime theo đúng quyền của role.
- Xem đầy đủ lịch sử chat của khách hàng để nắm ngữ cảnh.
- Đóng ticket sau khi xử lý xong.
- Cho phép super_admin xem dashboard thống kê đơn giản.

### 5. AI Core

AI Core là lớp tự động hóa của hệ thống.

- Phân loại ý định của khách hàng: question, complaint, hoặc spam.
- Trả lời câu hỏi bằng RAG dựa trên tài liệu đã upload.
- Tạo ticket khi phát hiện khiếu nại hoặc tin nhắn khẩn cấp.
- Tạo ticket khi RAG không tìm được context phù hợp vượt ngưỡng.
- Gửi push notification cho ticket khẩn cấp.
- Nhận webhook từ Facebook Messenger và email.
- Đồng bộ realtime giữa Web Admin và Mobile App.

## Mô hình dữ liệu

| Bảng | Mục đích | Trường chính |
| --- | --- | --- |
| `users` | Tài khoản nội bộ và RBAC. | `id`, `email`, `full_name`, `role`, `status`, `avatar_url`, `last_seen_at` |
| `tickets` | Ca hội thoại cần theo dõi. | `id`, `customer_id`, `customer_name`, `source`, `status`, `intent`, `summary`, `assigned_to`, `resolved_at` |
| `messages` | Lịch sử chat của từng ticket. | `id`, `ticket_id`, `sender_type`, `sender_id`, `content`, `created_at` |
| `documents` | File knowledge base đã upload. | `id`, `name`, `file_url`, `file_type`, `embedding_status`, `chunk_count`, `uploaded_by` |
| `channels` | Cấu hình Web, Facebook, và Email. | `id`, `type`, `config`, `is_active`, `connected_at` |
| `notifications` | Thông báo push/browser được lưu. | `id`, `ticket_id`, `recipient_id`, `title`, `body`, `is_read`, `sent_at` |

### Enum

| Trường | Giá trị |
| --- | --- |
| `users.role` | `super_admin`, `agent` |
| `users.status` | `online`, `offline`, `disabled` |
| `tickets.source` / `channels.type` | `web`, `facebook`, `email` |
| `tickets.status` | `open`, `in_progress`, `pending`, `resolved` |
| `tickets.intent` | `question`, `complaint`, `spam` |
| `messages.sender_type` | `customer`, `bot`, `human` |
| `documents.file_type` | `pdf`, `docx`, `txt` |
| `documents.embedding_status` | `processing`, `ready`, `error` |

## Công nghệ sử dụng

| Lớp | Công nghệ |
| --- | --- |
| AI Agent | LangChain + Gemini API hoặc OpenAI GPT |
| Vector Database | ChromaDB |
| Backend API | FastAPI |
| Database và Auth | Supabase: PostgreSQL, Realtime, Auth |
| Web Frontend | Next.js + Tailwind CSS |
| Mobile App | Flutter |
| Tích hợp Email | Mailgun hoặc SendGrid Webhook/API |
| Tích hợp Facebook | Meta Messenger Platform API Webhook |
| Push Notification | Firebase Cloud Messaging |
| Hosting | Railway hoặc Render cho backend, Vercel cho web |

## Lộ trình thực hiện

| Giai đoạn | Thời gian | Cột mốc |
| --- | --- | --- |
| Giai đoạn 1: Lập kế hoạch & Cài đặt | Ngày 1-3 | Chốt database schema, API contract, wireframe, và môi trường phát triển |
| Giai đoạn 2: Phát triển cốt lõi | Ngày 4-12 | Xây dựng backend API, AI Agent, Web Admin, và Mobile App |
| Giai đoạn 3: Tích hợp & Kiểm thử | Ngày 13-16 | Kết nối các module, kiểm thử end-to-end, và sửa lỗi |
| Giai đoạn 4: Hoàn thiện & Báo cáo | Ngày 17-18 | Cải thiện UI, hoàn thành báo cáo, và quay video demo |

## Yêu cầu chức năng

### Chat Widget

- [ ] Hiển thị khung chat nổi ở góc phải màn hình.
- [ ] Gửi và nhận tin nhắn realtime.
- [ ] Hiển thị typing indicator khi AI đang xử lý.
- [ ] Hỗ trợ handoff từ AI sang nhân viên mà không reset lịch sử chat.
- [ ] Hiển thị badge nguồn kênh Web, Facebook, hoặc Email.
- [ ] Hiển thị fallback bận/lỗi khi hệ thống không lưu được message.

### Web Admin Dashboard: super_admin

- [ ] Đăng nhập bằng email/password qua Supabase Auth.
- [ ] Xem và reply tất cả tin nhắn từ Web, Facebook, và Email trong Unified Inbox.
- [ ] Lọc Inbox theo kênh và trạng thái ticket: Open, In Progress, Resolved.
- [ ] Hiển thị dashboard thống kê: tổng tin nhắn hôm nay, tỉ lệ AI xử lý, thời gian phản hồi trung bình, ticket đang mở, xu hướng 7 ngày, và top 5 câu hỏi.
- [ ] Upload PDF, DOCX, hoặc TXT cho Knowledge Base AI và xem trạng thái xử lý.
- [ ] Tạo/xóa tài khoản agent và phân quyền role.
- [ ] Cấu hình Facebook webhook và địa chỉ email nhận tin.

### Web Admin Dashboard: agent

- [ ] Đăng nhập bằng tài khoản do super_admin tạo.
- [ ] Xem và reply ticket được giao hoặc đang mở.
- [ ] Xem toàn bộ lịch sử chat của khách hàng.
- [ ] Cập nhật trạng thái ticket thành In Progress hoặc Resolved.
- [ ] Không hiển thị Dashboard, Knowledge Base, quản lý nhân sự, và cài đặt kênh.

### Mobile App

- [ ] Đăng nhập bằng cùng tài khoản với Web qua Supabase Auth.
- [ ] Cho phép người dùng chuyển trạng thái Online/Offline.
- [ ] Nhận push notification cho ticket mới hoặc tin nhắn khẩn cấp.
- [ ] Xem và reply tin nhắn realtime theo phân quyền role.
- [ ] Hiển thị đầy đủ ngữ cảnh chat của khách hàng.
- [ ] Đóng ticket sau khi xử lý.
- [ ] Hiển thị thống kê đơn giản cho super_admin.
- [ ] Mở đúng ticket khi người dùng bấm vào push notification.

### AI Core

- [ ] Phân loại intent của tin nhắn: question, complaint, hoặc spam.
- [ ] Trả lời câu hỏi thường gặp bằng RAG với top-3 chunk từ ChromaDB.
- [ ] Tạo ticket và gửi push notification khi phát hiện khiếu nại hoặc RAG thất bại.
- [ ] Nhận webhook từ Facebook Messenger và email.
- [ ] Đồng bộ realtime toàn bộ hệ thống qua Supabase Realtime.
- [ ] Bỏ qua spam sau khi phân loại.
- [ ] Mặc định xử lý như `question` và tiếp tục RAG khi LLM classifier timeout.

## Yêu cầu phi chức năng

- Performance: AI nên phản hồi câu hỏi thông thường trong dưới 5 giây.
- Availability: Hệ thống nên hỗ trợ tự động hóa CSKH 24/7.
- Scalability: Kiến trúc nên cho phép thêm các kênh mới như Zalo hoặc WhatsApp trong tương lai.
- Security: Token xác thực và API key của các kênh phải được bảo vệ, quyền theo role phải được kiểm tra ở server-side.
- Reliability: Realtime client cần hiển thị cảnh báo và tự retry khi mất kết nối.
- Agent presence: Agent tự chuyển offline sau 30 giây không có heartbeat.

## Demo cuối kỳ dự kiến

Dự án cuối cùng nên thể hiện đầy đủ luồng xử lý sau:

1. Admin upload tài liệu doanh nghiệp.
2. Khách hàng gửi tin nhắn qua chat widget hoặc kênh giả lập.
3. AI phân loại intent của khách hàng.
4. AI trả lời câu hỏi thông thường dựa trên tài liệu đã upload.
5. AI tạo ticket khẩn cấp cho khiếu nại hoặc ca khó.
6. Nhân viên nhận thông báo trên mobile.
7. Nhân viên xem ngữ cảnh chat và xử lý ticket.

## Giới hạn hiện tại

- Demo local dùng auth/session mock và dữ liệu in-memory hoặc browser local khi chưa cấu hình Supabase thật.
- Widget demo trên Web có thể dùng response mock ổn định trong browser; các lệnh curl trong `docs/local-demo.md` kiểm thử API và AI service local thật.
- Facebook, Email, FCM, Supabase Auth, và ChromaDB hosted cần cấu hình provider trước khi chạy production.
- Channel settings và staff invite đang là boundary UI/API an toàn không trả secret ra client, nhưng lưu credential thật và gửi invite thật vẫn cần wiring production.
- Rate limiting khi deploy nhiều instance nên chuyển từ in-memory sang Redis, API gateway, hoặc edge provider.
- Không commit screenshot vì screenshot chỉ nên được tạo từ app đang chạy ngay trước lúc thuyết trình hoặc nộp bài.

## Lệnh kiểm thử

Chạy bộ kiểm thử cuối:

```sh
cd services/api && .venv/bin/python -m pytest
cd services/ai && .venv/bin/python -m pytest
cd apps/web-admin && ./node_modules/.bin/next lint
cd apps/web-admin && ./node_modules/.bin/vitest run
cd apps/web-admin && ./node_modules/.bin/next build
cd apps/mobile && flutter analyze
cd apps/mobile && flutter test
```

## Thông tin repository

| Mục | Thông tin |
| --- | --- |
| Cập nhật lần cuối | 2026-08-08 |
| Repository | `[GitHub repository link]` |
