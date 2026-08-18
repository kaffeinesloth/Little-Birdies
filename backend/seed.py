"""
Seed Data Script — Smart Helpdesk (SportGear Boutique)
Khởi tạo dữ liệu mẫu chuẩn chất lượng cao cho Web Admin & Store Testing.

Cách chạy:
    python seed.py
"""
import os
import sys
from dotenv import load_dotenv

load_dotenv()

# Fix encoding
if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8")

from supabase import create_client

SUPABASE_URL = os.getenv("SUPABASE_URL", "")
SUPABASE_SERVICE_KEY = os.getenv("SUPABASE_SERVICE_KEY", "")

if not SUPABASE_URL or not SUPABASE_SERVICE_KEY:
    print("❌ LỖI: Vui lòng điền SUPABASE_URL và SUPABASE_SERVICE_KEY trong file .env trước khi chạy seed!")
    sys.exit(1)

supabase = create_client(SUPABASE_URL, SUPABASE_SERVICE_KEY)


def seed_database():
    print("🌱 Bắt đầu dọn dẹp và khởi tạo dữ liệu mẫu chuẩn...")

    # 1. Dọn dẹp dữ liệu cũ (Xóa messages trước, tickets sau)
    try:
        # Lấy danh sách ID tickets hiện có để xóa
        old_tickets = supabase.table("tickets").select("id").execute()
        if old_tickets.data:
            t_ids = [t["id"] for t in old_tickets.data]
            for tid in t_ids:
                supabase.table("messages").delete().eq("ticket_id", tid).execute()
            supabase.table("tickets").delete().neq("id", "00000000-0000-0000-0000-000000000000").execute()
            print("  🧹 Đã dọn dẹp sạch sẽ danh sách ticket và tin nhắn rác cũ.")
    except Exception as e:
        print("  ⚠️ Không thể xóa toàn bộ dữ liệu cũ (có thể tiếp tục):", e)

    # 2. Channels
    channels = [
        {"type": "web", "is_active": True, "config": {"widget_color": "#0284C7"}},
        {"type": "facebook", "is_active": True, "config": {"page_name": "SportGear Boutique Fanpage"}},
        {"type": "email", "is_active": True, "config": {"support_email": "support@sportgear.vn"}},
    ]
    for c in channels:
        supabase.table("channels").upsert(c, on_conflict="type").execute()
    print("  ✅ 3 Kênh giao tiếp (Web, Facebook, Email) đã được kích hoạt.")

    # 3. Danh sách Tickets mẫu thực tế của SportGear Boutique
    sample_tickets = [
        {
            "customer_id": "cust_web_9821",
            "customer_name": "Nguyễn Minh Khang (Web Store)",
            "source": "web",
            "status": "open",
            "intent": "question",
            "summary": "Tư vấn chọn size Áo Polo Pro Active và hỏi chính sách freeship",
        },
        {
            "customer_id": "psid_fb_4482",
            "customer_name": "Trần Thị Thu Hà",
            "source": "facebook",
            "status": "in_progress",
            "intent": "question",
            "summary": "Hỏi thời gian mở cửa chi nhánh Quận 1 và giao hỏa tốc giày Ultra Boost",
        },
        {
            "customer_id": "hoangnam.sport@gmail.com",
            "customer_name": "Lê Hoàng Nam",
            "source": "email",
            "status": "resolved",
            "intent": "question",
            "summary": "Hỏi về chính sách bảo hành giày thể thao và đổi trả 30 ngày",
        },
        {
            "customer_id": "cust_web_1204",
            "customer_name": "Phạm Quốc Bảo (Khách VIP)",
            "source": "web",
            "status": "in_progress",
            "intent": "complaint",
            "summary": "Cần hỗ trợ đổi sang size 43 cho đơn hàng Giày Ultra Boost 2026",
        },
    ]

    ticket_ids = []
    for t in sample_tickets:
        res = supabase.table("tickets").insert(t).execute()
        if res.data:
            ticket_ids.append(res.data[0]["id"])
    print(f"  ✅ Đã tạo {len(ticket_ids)} Tickets thực tế chuẩn SportGear Boutique.")

    # 4. Messages cho Ticket 1 (Web Store: Polo + Freeship)
    if len(ticket_ids) >= 1:
        supabase.table("messages").insert([
            {
                "ticket_id": ticket_ids[0],
                "sender_type": "customer",
                "sender_id": "cust_web_9821",
                "content": "Shop ơi mình cao 1m72 nặng 70kg thì mặc áo Polo Pro Active size nào vừa và đơn bao nhiêu được freeship ạ?",
            },
            {
                "ticket_id": ticket_ids[0],
                "sender_type": "bot",
                "sender_id": "ai-bot",
                "content": "Dạ chào bạn! Với chiều cao 1m72 nặng 70kg, bạn mặc size L áo Polo Pro Active là vừa vặn và thoải mái nhất ạ. Đơn hàng từ 500.000đ bên mình miễn phí vận chuyển toàn quốc bạn nhé!",
            },
        ]).execute()

    # 5. Messages cho Ticket 2 (FB: Giờ mở cửa + Hỏa tốc)
    if len(ticket_ids) >= 2:
        supabase.table("messages").insert([
            {
                "ticket_id": ticket_ids[1],
                "sender_type": "customer",
                "sender_id": "psid_fb_4482",
                "content": "Shop ơi chi nhánh 120 Nguyễn Trãi Quận 1 mở cửa đến mấy giờ ạ? Mình muốn đặt giày Ultra Boost giao hỏa tốc 2h được không?",
            },
            {
                "ticket_id": ticket_ids[1],
                "sender_type": "bot",
                "sender_id": "ai-bot",
                "content": "Dạ chi nhánh 120 Nguyễn Trãi Quận 1 mở cửa từ 8:00 đến 21:30 tất cả các ngày trong tuần ạ. Shop có hỗ trợ giao hỏa tốc trong 2h nội thành TP.HCM cho giày Ultra Boost bạn nhé!",
            },
            {
                "ticket_id": ticket_ids[1],
                "sender_type": "human",
                "sender_id": "agent_demo",
                "content": "Dạ em chào chị Hà, em đã chuẩn bị sẵn size 38 màu Xanh Neon cho chị rồi ạ, shipper sẽ giao hỏa tốc đến chị trong 2h tới nhé!",
            },
        ]).execute()

    # 6. Messages cho Ticket 3 (Email: Chính sách đổi trả)
    if len(ticket_ids) >= 3:
        supabase.table("messages").insert([
            {
                "ticket_id": ticket_ids[2],
                "sender_type": "customer",
                "sender_id": "hoangnam.sport@gmail.com",
                "content": "Xin hỏi SportGear quy định đổi trả hàng và bảo hành như thế nào?",
            },
            {
                "ticket_id": ticket_ids[2],
                "sender_type": "bot",
                "sender_id": "ai-bot",
                "content": "Dạ SportGear hỗ trợ đổi size/mẫu miễn phí trong vòng 30 ngày (sản phẩm còn nguyên tem mác). Giày thể thao và Balo được bảo hành chính hãng 6 tháng keo, chỉ may ạ.",
            },
        ]).execute()

    # 7. Messages cho Ticket 4 (Web Store: Đổi size giày)
    if len(ticket_ids) >= 4:
        supabase.table("messages").insert([
            {
                "ticket_id": ticket_ids[3],
                "sender_type": "customer",
                "sender_id": "cust_web_1204",
                "content": "Chào shop, hôm qua mình có mua giày Ultra Boost size 42 nhưng mang hơi kích ngón chân, mình muốn đổi lên size 43 nhé.",
            },
            {
                "ticket_id": ticket_ids[3],
                "sender_type": "bot",
                "sender_id": "ai-bot",
                "content": "Dạ chào anh Bảo, anh yên tâm nhé! Shop có chính sách đổi size tận nhà trong 30 ngày. Em sẽ chuyển yêu cầu để nhân viên CSKH liên hệ hỗ trợ đổi size 43 cho anh ngay ạ!",
            },
            {
                "ticket_id": ticket_ids[3],
                "sender_type": "human",
                "sender_id": "agent_demo",
                "content": "Dạ em chào anh Bảo, em đã tạo phiếu đổi size 43 cho anh. Ngày mai shipper bên em sẽ mang đôi mới đến tận nhà đổi và thu lại đôi cũ cho anh hoàn toàn miễn phí ạ!",
            },
        ]).execute()

    print("  ✅ Đã khởi tạo đầy đủ các cuộc hội thoại chuẩn mực.")
    print("\n🎉 HOÀN THÀNH SEED DỮ LIỆU THỰC TẾ CHO SPORTGEAR BOUTIQUE!")


if __name__ == "__main__":
    seed_database()
