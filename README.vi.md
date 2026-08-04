# Smart Helpdesk - Hệ thống CSKH tự động bằng AI

Smart Helpdesk là nền tảng SaaS giúp các shop online vừa và nhỏ tự động hóa chăm sóc khách hàng bằng AI Agent, Retrieval-Augmented Generation (RAG), và quy trình quản lý ticket đơn giản. Hệ thống có thể tự động trả lời các câu hỏi lặp lại, phân loại ý định của khách hàng, và chuyển các khiếu nại khẩn cấp cho nhân viên thông qua ứng dụng mobile.

> Khẩu hiệu: "Tự động hóa CSKH. Xử lý khiếu nại tức thì."

## Thông tin nhóm

| # | Họ và tên | MSSV | Vai trò | Trách nhiệm chính |
| --- | --- | --- | --- | --- |
| 1 | Huỳnh Bá Anh Khoa | N22DCCN141 | Frontend Developer | Xây dựng Web Admin Dashboard, giao diện chat widget, trang demo chat, và giao diện responsive |
| 2 | Vũ Kim Long | N22DCCN050 | Backend Developer | Xây dựng REST API, database models, quy trình ticket, authentication, và tích hợp dịch vụ |
| 3 | Trần Tuấn Hải | N22DCCN026 | AI Engineer | Xây dựng RAG pipeline, intent classification, tạo câu trả lời bằng AI, và tích hợp LLM |
| 4 | Đặng Nhật Nam | N22DCDT038 | Documentation & QA | Chuẩn bị tài liệu dự án, kiểm thử luồng người dùng, hỗ trợ viết báo cáo, và kiểm tra yêu cầu chức năng |
| 5 | Tạ Quang An | N22DCAT003 | Mobile App & QA | Xây dựng/hỗ trợ luồng ticket trên mobile, push notification, và kiểm thử end-to-end |

| Mục | Thông tin |
| --- | --- |
| Môn học | Đồ án AI Helpdesk Agent / AI Development / Product Development Track |
| Giảng viên hướng dẫn | `[Tên giảng viên hướng dẫn]` |
| Năm học | 2025 - 2026 |
| Hạn nộp | `[Ngày nộp]` |

## Tổng quan dự án

| Trường | Nội dung |
| --- | --- |
| Tên dự án | Smart Helpdesk - AI-Powered Customer Support System |
| Loại sản phẩm | SaaS Platform: Web Admin + Mobile App + AI Agent |
| Lĩnh vực | Customer Service / SaaS |
| Người dùng mục tiêu | Chủ shop online vừa và nhỏ, người bán hàng thương mại điện tử, nhân viên CSKH |
| Công nghệ cốt lõi | LLM, RAG, LangChain, FastAPI, Supabase, Flutter |
| Mục tiêu chính | Giảm công việc CSKH lặp lại và tránh bỏ sót các tin nhắn khẩn cấp |
| Thời gian phát triển | 3 tuần |

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
- Intent Classification: Nhận diện tin nhắn là câu hỏi thông thường, ý định mua hàng, khiếu nại, hay vấn đề khẩn cấp.
- Omnichannel Unified Inbox: Gom tin nhắn từ website chat, Facebook Messenger, và email vào một hệ thống hỗ trợ duy nhất.
- Web Admin Dashboard: Cho phép chủ doanh nghiệp upload tài liệu, quản lý ticket, xem báo cáo, và quản lý nhân viên CSKH.
- Mobile App cho nhân viên: Gửi thông báo ticket khẩn cấp và cho phép nhân viên xử lý các ca khó mọi lúc mọi nơi.

## Tác động kỳ vọng

| Chỉ số | Trước Smart Helpdesk | Sau Smart Helpdesk |
| --- | --- | --- |
| Thời gian phản hồi trung bình | 15-30 phút ngoài giờ làm việc | Dưới 5 giây với câu hỏi AI xử lý được |
| Tỉ lệ tin nhắn AI xử lý | 0% | Khoảng 80% với câu hỏi lặp lại |
| Tỉ lệ bỏ sót khiếu nại | Khoảng 15% | Gần 0% nhờ push notification khẩn cấp |
| Nhân sự cần trực page | 2 người mỗi ca | 1 người, chỉ tập trung vào ca khó |

## Kiến trúc hệ thống

```text
PHÍA KHÁCH HÀNG
Web Chat Widget / Facebook Messenger / Email Inbox
        |
        | Tin nhắn và webhook
        v
BACKEND & AI CORE
        |
        +--> Intent Classifier
        |       |
        |       +--> Khiếu nại hoặc vấn đề khẩn cấp
        |       |       +--> Tạo Ticket
        |       |       +--> Gửi Push Notification
        |       |
        |       +--> Câu hỏi thông thường
        |               +--> RAG Agent
        |               +--> Tìm trong tài liệu đã upload
        |               +--> Tự động trả lời khách hàng
        |
        +--> Đồng bộ Ticket realtime
                |
                +--> Mobile App cho nhân viên
                +--> Web Admin Dashboard cho chủ shop/quản lý
```

## Các module chính

### 1. Chat Widget

Chat widget được khách hàng sử dụng trên website của doanh nghiệp.

- Hiển thị khung chat ở góc dưới bên phải website.
- Gửi và nhận tin nhắn text theo thời gian thực.
- Hiển thị typing indicator khi AI đang xử lý.
- Hỗ trợ chuyển giao từ AI sang nhân viên thật mà không reset đoạn chat.

### 2. Web Admin Dashboard

Admin dashboard được sử dụng bởi chủ shop và quản lý.

- Đăng nhập và phân quyền theo vai trò manager/staff.
- Upload file PDF hoặc Word để tạo knowledge base cho AI.
- Xem danh sách ticket và trạng thái: Open, Pending, Resolved.
- Xem thống kê dashboard như số tin nhắn, tỉ lệ AI tự xử lý, và thời gian phản hồi trung bình.
- Quản lý tài khoản nhân viên CSKH.

### 3. Mobile App

Mobile app được sử dụng bởi nhân viên CSKH.

- Đăng nhập và bật/tắt trạng thái Online/Offline.
- Nhận push notification khi có ticket khẩn cấp.
- Xem đầy đủ lịch sử chat của khách hàng để nắm ngữ cảnh.
- Chat trực tiếp với khách hàng theo thời gian thực.
- Đóng ticket sau khi xử lý xong.

### 4. AI Core

AI Core là lớp tự động hóa của hệ thống.

- Phân loại ý định của khách hàng.
- Trả lời câu hỏi bằng RAG dựa trên tài liệu đã upload.
- Tạo ticket khi phát hiện khiếu nại hoặc tin nhắn khẩn cấp.
- Gửi push notification cho ticket khẩn cấp.
- Nhận webhook từ Facebook Messenger và email.
- Đồng bộ realtime giữa Web Admin và Mobile App.

## Công nghệ sử dụng

| Lớp | Công nghệ |
| --- | --- |
| AI Agent | LangChain + Gemini API hoặc OpenAI GPT |
| Vector Database | ChromaDB hoặc Pinecone |
| Backend API | FastAPI |
| Database và Auth | Supabase: PostgreSQL, Realtime, Auth |
| Web Frontend | Next.js + Tailwind CSS |
| Mobile App | Flutter |
| Tích hợp Email | Mailgun hoặc SendGrid Webhook |
| Tích hợp Facebook | Meta Messenger Platform API Webhook |
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

- [ ] Hiển thị khung chat trên website.
- [ ] Gửi và nhận tin nhắn realtime.
- [ ] Hiển thị typing indicator khi AI đang xử lý.
- [ ] Hỗ trợ handoff từ AI sang nhân viên.

### Web Admin Dashboard

- [ ] Hỗ trợ đăng nhập và phân quyền.
- [ ] Upload file PDF/Word cho knowledge base.
- [ ] Hiển thị danh sách ticket và trạng thái ticket.
- [ ] Hiển thị dashboard thống kê.
- [ ] Quản lý tài khoản nhân viên.

### Mobile App

- [ ] Hỗ trợ đăng nhập cho nhân viên.
- [ ] Cho phép nhân viên chuyển trạng thái Online/Offline.
- [ ] Nhận push notification cho ticket khẩn cấp.
- [ ] Hiển thị đầy đủ ngữ cảnh chat của khách hàng.
- [ ] Hỗ trợ chat realtime với khách hàng.
- [ ] Đóng ticket sau khi xử lý.

### AI Core

- [ ] Phân loại intent của tin nhắn.
- [ ] Trả lời câu hỏi thường gặp bằng RAG.
- [ ] Tạo ticket khẩn cấp cho khiếu nại.
- [ ] Nhận webhook từ Facebook Messenger và email.
- [ ] Đồng bộ realtime giữa web và mobile.

## Yêu cầu phi chức năng

- Performance: AI nên phản hồi câu hỏi thông thường trong dưới 5 giây.
- Availability: Hệ thống nên hỗ trợ tự động hóa CSKH 24/7.
- Scalability: Kiến trúc nên cho phép thêm các kênh mới như Zalo hoặc WhatsApp trong tương lai.
- Security: Token xác thực phải được bảo vệ, và dữ liệu chat không nên lưu dưới dạng plain text.

## Demo cuối kỳ dự kiến

Dự án cuối cùng nên thể hiện đầy đủ luồng xử lý sau:

1. Admin upload tài liệu doanh nghiệp.
2. Khách hàng gửi tin nhắn qua chat widget hoặc kênh giả lập.
3. AI phân loại intent của khách hàng.
4. AI trả lời câu hỏi thông thường dựa trên tài liệu đã upload.
5. AI tạo ticket khẩn cấp cho khiếu nại hoặc ca khó.
6. Nhân viên nhận thông báo trên mobile.
7. Nhân viên xem ngữ cảnh chat và xử lý ticket.

## Thông tin repository

| Mục | Thông tin |
| --- | --- |
| Cập nhật lần cuối | 2026-08-04 |
| Repository | `[GitHub repository link]` |
