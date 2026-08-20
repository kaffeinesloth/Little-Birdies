"""
Repeatable demo seed for Smart Helpdesk / SportGear Boutique.

Default behavior is safe for shared Supabase projects:
    python seed.py

It refreshes only the known SportGear demo tickets/messages and upserts channels.
It does not delete real customer tickets.

Destructive full reset, only when you intentionally want to wipe all tickets:
    python seed.py --reset-all --yes
"""
from __future__ import annotations

import argparse
import os
import sys
from typing import Iterable

from dotenv import load_dotenv

load_dotenv()

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8")

SUPABASE_URL = os.getenv("SUPABASE_URL", "")
SUPABASE_SERVICE_KEY = os.getenv("SUPABASE_SERVICE_KEY", "")

DEMO_CUSTOMER_IDS = [
    "cust_web_9821",
    "psid_fb_4482",
    "hoangnam.sport@gmail.com",
    "cust_web_1204",
]

CHANNELS = [
    {"type": "web", "is_active": True, "config": {"widget_color": "#0284C7"}},
    {"type": "facebook", "is_active": True, "config": {"page_name": "SportGear Boutique Fanpage"}},
    {"type": "email", "is_active": True, "config": {"support_email": "support@sportgear.vn"}},
]

SAMPLE_TICKETS = [
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


def _messages_for(ticket_ids: list[str]) -> list[dict]:
    return [
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
    ]


def _require_env() -> None:
    if not SUPABASE_URL or not SUPABASE_SERVICE_KEY:
        print("ERROR: Set SUPABASE_URL and SUPABASE_SERVICE_KEY in backend/.env before seeding.")
        raise SystemExit(1)


def _delete_tickets(supabase, ticket_ids: Iterable[str]) -> int:
    count = 0
    for ticket_id in ticket_ids:
        supabase.table("messages").delete().eq("ticket_id", ticket_id).execute()
        supabase.table("tickets").delete().eq("id", ticket_id).execute()
        count += 1
    return count


def _refresh_demo_tickets(supabase) -> None:
    existing = (
        supabase.table("tickets")
        .select("id, customer_id")
        .in_("customer_id", DEMO_CUSTOMER_IDS)
        .execute()
    )
    ticket_ids = [row["id"] for row in (existing.data or [])]
    if ticket_ids:
        deleted = _delete_tickets(supabase, ticket_ids)
        print(f"  Removed {deleted} existing SportGear demo tickets/messages.")
    else:
        print("  No existing SportGear demo tickets found.")


def _reset_all_tickets(supabase, yes: bool) -> None:
    if not yes:
        print("ERROR: --reset-all deletes every ticket/message. Re-run with --reset-all --yes if intentional.")
        raise SystemExit(2)

    print("WARNING: deleting ALL tickets/messages in this Supabase project.")
    old_tickets = supabase.table("tickets").select("id").execute()
    ticket_ids = [row["id"] for row in (old_tickets.data or [])]
    deleted = _delete_tickets(supabase, ticket_ids)
    print(f"  Removed {deleted} total tickets/messages.")


def seed_database(reset_all: bool = False, yes: bool = False) -> None:
    _require_env()
    from supabase import create_client

    supabase = create_client(SUPABASE_URL, SUPABASE_SERVICE_KEY)

    print("Seeding SportGear demo data.")
    if reset_all:
        _reset_all_tickets(supabase, yes=yes)
    else:
        print("Safe mode: refreshing only known SportGear demo tickets.")
        _refresh_demo_tickets(supabase)

    for channel in CHANNELS:
        supabase.table("channels").upsert(channel, on_conflict="type").execute()
    print("  Upserted web/facebook/email demo channels.")

    ticket_ids: list[str] = []
    for ticket in SAMPLE_TICKETS:
        res = supabase.table("tickets").insert(ticket).execute()
        if res.data:
            ticket_ids.append(res.data[0]["id"])

    if len(ticket_ids) != len(SAMPLE_TICKETS):
        raise RuntimeError(f"Expected {len(SAMPLE_TICKETS)} tickets, created {len(ticket_ids)}")

    messages = _messages_for(ticket_ids)
    supabase.table("messages").insert(messages).execute()
    print(f"  Created {len(ticket_ids)} demo tickets and {len(messages)} messages.")
    print("Done. Flutter staff UI and analytics now have repeatable SportGear demo data.")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Seed repeatable Smart Helpdesk demo data.")
    parser.add_argument(
        "--reset-all",
        action="store_true",
        help="Delete all tickets/messages before inserting demo data. Requires --yes.",
    )
    parser.add_argument(
        "--yes",
        action="store_true",
        help="Confirm destructive --reset-all operation.",
    )
    return parser.parse_args()


if __name__ == "__main__":
    args = parse_args()
    seed_database(reset_all=args.reset_all, yes=args.yes)
