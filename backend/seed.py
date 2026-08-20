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
        "customer_name": "Khang Nguyen (Web Store)",
        "source": "web",
        "status": "open",
        "intent": "question",
        "summary": "Asked about Polo Pro Active sizing and free shipping",
    },
    {
        "customer_id": "psid_fb_4482",
        "customer_name": "Ha Tran",
        "source": "facebook",
        "status": "in_progress",
        "intent": "question",
        "summary": "Asked about District 1 opening hours and Ultra Boost express delivery",
    },
    {
        "customer_id": "hoangnam.sport@gmail.com",
        "customer_name": "Nam Le",
        "source": "email",
        "status": "resolved",
        "intent": "question",
        "summary": "Asked about athletic-shoe warranties and 30-day returns",
    },
    {
        "customer_id": "cust_web_1204",
        "customer_name": "Bao Pham (VIP Customer)",
        "source": "web",
        "status": "in_progress",
        "intent": "complaint",
        "summary": "Needs help exchanging an Ultra Boost 2026 order for size 43",
    },
]


def _messages_for(ticket_ids: list[str]) -> list[dict]:
    return [
        {
            "ticket_id": ticket_ids[0],
            "sender_type": "customer",
            "sender_id": "cust_web_9821",
            "content": "I am 1.72 m tall and weigh 70 kg. Which Polo Pro Active size fits, and what order value qualifies for free shipping?",
        },
        {
            "ticket_id": ticket_ids[0],
            "sender_type": "bot",
            "sender_id": "ai-bot",
            "content": "At 1.72 m and 70 kg, size L in the Polo Pro Active should provide the best fit. Orders from 500,000 VND receive free nationwide shipping.",
        },
        {
            "ticket_id": ticket_ids[1],
            "sender_type": "customer",
            "sender_id": "psid_fb_4482",
            "content": "What time does the 120 Nguyen Trai, District 1 store close? Can Ultra Boost shoes be delivered within two hours?",
        },
        {
            "ticket_id": ticket_ids[1],
            "sender_type": "bot",
            "sender_id": "ai-bot",
            "content": "The 120 Nguyen Trai, District 1 store is open daily from 08:00 to 21:30. Two-hour Ultra Boost delivery is available in central Ho Chi Minh City.",
        },
        {
            "ticket_id": ticket_ids[1],
            "sender_type": "human",
            "sender_id": "agent_demo",
            "content": "Size 38 in Neon Blue is ready. The courier will deliver it within the next two hours.",
        },
        {
            "ticket_id": ticket_ids[2],
            "sender_type": "customer",
            "sender_id": "hoangnam.sport@gmail.com",
            "content": "What are SportGear's return and warranty policies?",
        },
        {
            "ticket_id": ticket_ids[2],
            "sender_type": "bot",
            "sender_id": "ai-bot",
            "content": "SportGear offers free size or model exchanges within 30 days when tags remain attached. Athletic shoes and backpacks have a six-month warranty for adhesive and stitching defects.",
        },
        {
            "ticket_id": ticket_ids[3],
            "sender_type": "customer",
            "sender_id": "cust_web_1204",
            "content": "I bought Ultra Boost size 42 yesterday, but it is tight around my toes. I would like to exchange it for size 43.",
        },
        {
            "ticket_id": ticket_ids[3],
            "sender_type": "bot",
            "sender_id": "ai-bot",
            "content": "SportGear offers at-home size exchanges within 30 days. I will transfer this request to an agent to arrange size 43.",
        },
        {
            "ticket_id": ticket_ids[3],
            "sender_type": "human",
            "sender_id": "agent_demo",
            "content": "Your size 43 exchange was created. Tomorrow, a courier will deliver the new pair and collect the old one at no charge.",
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
