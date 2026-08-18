import re
import os

MAIN_DART = r'mobile/lib/main.dart'

with open(MAIN_DART, 'r', encoding='utf-8') as f:
    content = f.read()

# 1. Update Supabase Keys
content = content.replace(
    "'https://YOUR_SUPABASE_PROJECT.supabase.co'", 
    "'https://djgvczqdtysefrdmujrr.supabase.co'"
)
content = content.replace(
    "'YOUR_SUPABASE_ANON_KEY'", 
    "'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImRqZ3ZjenFkdHlzZ" +
    "WZyZG11anJyIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODY0MDMyODAsImV4cCI6MjEwMTk3OTI4MH0.sRdLhWHSV6OF6wjnvXsTwTyhxLl7yS5MQYOMvkKadiw'"
)

# 2. Fix Vietnamese Accents (Prominent strings)
replacements = {
    'He thong quan ly hop nhat kenh Web Store & Facebook Messenger + RAG KB': 'Hệ thống quản lý hợp nhất kênh Web Store & Facebook Messenger + RAG KB',
    'Khach hang': 'Khách hàng',
    'Khach Hang Web': 'Khách Hàng Web',
    'San pham bi rach, khach yeu cau shop xu ly ngay va can nhan vien tiep nhan.': 'Sản phẩm bị rách, khách yêu cầu shop xử lý ngay và cần nhân viên tiếp nhận.',
    'San pham bi rach roi, shop xu ly giup toi ngay duoc khong?': 'Sản phẩm bị rách rồi, shop xử lý giúp tôi ngay được không?',
    'San pham bi rach roi, shop lam an kieu gi the?! Xu ly ngay!': 'Sản phẩm bị rách rồi, shop làm ăn kiểu gì thế?! Xử lý ngay!',
    'Da chao ban, shop da tiep nhan su co hang bi rach. Ben minh se gui san pham moi bu ngay trong hom nay.': 'Dạ chào bạn, shop đã tiếp nhận sự cố hàng bị rách. Bên mình sẽ gửi sản phẩm mới bù ngay trong hôm nay.',
    'Quan Ly Chat & Ticket': 'Quản Lý Chat & Ticket',
    'Bao cao Analytics': 'Báo cáo Analytics',
    'Nhan vien CSKH': 'Nhân viên CSKH',
    'Tat ca': 'Tất cả',
    'Hoan thanh': 'Hoàn thành',
    'Dang xu ly': 'Đang xử lý',
    'Moi tao': 'Mới tạo',
    'Phan nan': 'Phàn nàn',
    'Hoi dap': 'Hỏi đáp',
    'Khong biet': 'Không biết',
    'Tim kiem ticket, khach hang...': 'Tìm kiếm ticket, khách hàng...',
    'Bo loc': 'Bộ lọc',
    'Thong tin khach hang': 'Thông tin khách hàng',
    'Lich su mua hang': 'Lịch sử mua hàng',
    'Dang phan hoi tu dong...': 'Đang phản hồi tự động...',
    'Vui long cho toi gap nhan vien.': 'Vui lòng cho tôi gặp nhân viên.',
    'Khach hoi thoi gian bao hanh va chinh sach doi tra.': 'Khách hỏi thời gian bảo hành và chính sách đổi trả.',
    'Don hang cua toi tre 3 ngay roi. Vui long cho toi gap nhan vien.': 'Đơn hàng của tôi trễ 3 ngày rồi. Vui lòng cho tôi gặp nhân viên.',
    'Theo bang size, anh nen chon size XL de thoai mai khi van dong.': 'Theo bảng size, anh nên chọn size XL để thoải mái khi vận động.',
    'Minh cao 1m75 nang 72kg thi mac size nao?': 'Mình cao 1m75 nặng 72kg thì mặc size nào?'
}

for old, new in replacements.items():
    content = content.replace(old, new)

with open(MAIN_DART, 'w', encoding='utf-8') as f:
    f.write(content)

print("Done replacing accents and Supabase keys.")
