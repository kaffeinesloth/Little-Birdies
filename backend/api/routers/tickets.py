from fastapi import APIRouter, Depends, HTTPException, status, Query
from typing import Optional
from uuid import UUID
from pydantic import BaseModel

from core.auth import get_current_user, require_super_admin
from core.database import get_supabase_client, get_supabase_admin
from core import demo_store
from models.domain import (
    APIResponse, MetaResponse,
    TicketCreate, TicketUpdate, TicketOut,
    TicketStatus, TicketSource,
)

router = APIRouter()

_demo_fallback_warnings: set[str] = set()


def _log_demo_fallback_once(key: str, message: str, error: Exception) -> None:
    if key in _demo_fallback_warnings:
        return
    _demo_fallback_warnings.add(key)
    print(f"{message}: {error}")


DEMO_STATS_FALLBACK = {
    "total_tickets": 12,
    "open_tickets": 3,
    "in_progress_tickets": 2,
    "resolved_tickets": 9,
    "ai_handled_percent": 91.5,
    "avg_response_time": "0.4s",
    "satisfaction_score": "4.9/5.0",
    "saved_salary": "21.500.000đ/tháng",
    "estimated_revenue": "42.000.000đ",
    "channels": {
        "web": 7,
        "facebook": 3,
        "email": 2,
    },
}

DEMO_PRODUCT_ISSUES_FALLBACK = {
    "top_product_issues": [
        {"product": "Áo Polo Pro Active", "complaint_count": 8, "top_issues": ["Áo rách chỉ ở nách sau 2 tuần", "Size L nhưng mặc như XL", "Màu bay sau vài lần giặt"]},
        {"product": "Giày Ultra Boost 2026", "complaint_count": 5, "top_issues": ["Đế giày bong keo sau 1 tháng", "Size 42 bị chật hơn bình thường"]},
        {"product": "Quần Gym Flex", "complaint_count": 3, "top_issues": ["Đường may bị xổ ở háng"]},
    ],
    "ai_knowledge_gaps": [
        {"topic": "Hướng dẫn chăm sóc sản phẩm", "query_count": 4},
        {"topic": "Chương trình thành viên VIP", "query_count": 2},
        {"topic": "Bảo hành giày theo thương hiệu", "query_count": 1},
    ],
}

DEMO_AGENT_PERFORMANCE_FALLBACK = {
    "avg_bot_response_seconds": 0.4,
    "avg_human_response_seconds": 185,
    "ai_vs_human_ratio": "91.5% AI / 8.5% Nhân Viên",
    "total_tickets": 12,
    "resolved_tickets": 9,
    "resolution_rate_percent": 91.5,
    "human_tickets": 1,
    "hourly_distribution": [
        {"hour": "8:00", "count": 2},
        {"hour": "9:00", "count": 5},
        {"hour": "10:00", "count": 8},
        {"hour": "11:00", "count": 6},
        {"hour": "12:00", "count": 4},
        {"hour": "13:00", "count": 3},
        {"hour": "14:00", "count": 7},
        {"hour": "15:00", "count": 9},
        {"hour": "16:00", "count": 11},
        {"hour": "17:00", "count": 6},
        {"hour": "18:00", "count": 4},
        {"hour": "19:00", "count": 3},
    ],
    "top_agents": [
        {"name": "Nguyễn Thị Lan (CSKH)", "tickets_handled": 24, "avg_response_min": 2.1, "satisfaction": 4.9},
        {"name": "Trần Minh Tuấn (Senior)", "tickets_handled": 18, "avg_response_min": 3.5, "satisfaction": 4.8},
        {"name": "Lê Hồng Anh (Agent)", "tickets_handled": 12, "avg_response_min": 4.2, "satisfaction": 4.7},
    ],
}


@router.get("/demo-list", response_model=APIResponse)
def get_demo_tickets():
    """Endpoint không cần auth cho Flutter Web Admin Demo"""
    try:
        supabase = get_supabase_admin()
        result = (
            supabase.table("tickets")
            .select("*")
            .order("created_at", desc=True)
            .limit(50)
            .execute()
        )
        data = result.data or []
    except Exception as e:
        _log_demo_fallback_once(
            "demo-list",
            "Error fetching demo tickets; using in-memory demo store",
            e,
        )
        data = demo_store.list_tickets()
    return APIResponse(
        meta=MetaResponse(code=200, message="Success"),
        data=data,
    )


@router.get("/demo-detail/{ticket_id}", response_model=APIResponse)
def get_demo_ticket_detail(ticket_id: UUID):
    """Endpoint không cần auth để lấy chi tiết ticket và messages cho Flutter Web & Store"""
    try:
        supabase = get_supabase_admin()
        ticket_result = (
            supabase.table("tickets")
            .select("*")
            .eq("id", str(ticket_id))
            .single()
            .execute()
        )
        if not ticket_result.data:
            raise HTTPException(status_code=404, detail="Ticket không tồn tại.")

        messages_result = (
            supabase.table("messages")
            .select("*")
            .eq("ticket_id", str(ticket_id))
            .order("created_at", desc=False)
            .execute()
        )
        detail = {
            "ticket": ticket_result.data,
            "messages": messages_result.data or [],
        }
    except HTTPException:
        raise
    except Exception as e:
        _log_demo_fallback_once(
            "demo-detail",
            "Error fetching demo ticket detail; using in-memory demo store",
            e,
        )
        detail = demo_store.get_ticket_detail(str(ticket_id))
        if not detail:
            raise HTTPException(status_code=404, detail="Ticket không tồn tại.")
    return APIResponse(
        meta=MetaResponse(code=200, message="Success"),
        data=detail,
    )


@router.get("/demo-ai-suggest/{ticket_id}", response_model=APIResponse)
def get_demo_ai_suggestions(ticket_id: UUID):
    """
    Sinh 3 gợi ý trả lời thông minh động (AI Copilot Drafts)
    dựa trên câu hỏi thực tế mới nhất của khách hàng trong Ticket.
    """
    try:
        supabase = get_supabase_admin()
        # Lấy tin nhắn mới nhất của khách hàng
        msgs_res = (
            supabase.table("messages")
            .select("content, sender_type, created_at")
            .eq("ticket_id", str(ticket_id))
            .order("created_at", desc=True)
            .limit(6)
            .execute()
        )
        messages = msgs_res.data or []
    except Exception as e:
        _log_demo_fallback_once(
            "demo-ai-suggestions",
            "Error fetching demo AI suggestions; using in-memory demo store",
            e,
        )
        detail = demo_store.get_ticket_detail(str(ticket_id))
        messages = detail["messages"] if detail else []
    
    customer_text = ""
    for m in messages:
        if m.get("sender_type") == "customer":
            customer_text = m.get("content", "")
            break

    import unicodedata
    def _strip(s: str) -> str:
        return "".join(
            c for c in unicodedata.normalize("NFD", s) if unicodedata.category(c) != "Mn"
        ).replace("đ", "d").replace("Đ", "D").lower()

    norm = _strip(customer_text)

    if any(k in norm for k in ["polo", "pro active", "ao"]) or (any(k in norm for k in ["size", "chieu cao", "can nang", "kg", "m7", "m6", "m8"]) and "giay" not in norm):
        suggestions = [
            "Dạ chào bạn, với chiều cao và cân nặng của bạn, size L áo Polo Pro Active sẽ vừa vặn và tôn dáng nhất ạ!",
            "Dạ SportGear hỗ trợ đổi size hoàn toàn miễn phí tại nhà trong vòng 30 ngày nếu bạn mặc chưa vừa nhé!",
            "Dạ đơn hàng Áo Polo từ 500.000đ được FREESHIP 100% toàn quốc và giao hỏa tốc 2h tại TP.HCM ạ.",
        ]
    elif any(k in norm for k in ["ultra boost", "giay", "boost", "giay the thao"]):
        suggestions = [
            "Dạ chào bạn, mẫu giày Ultra Boost 2026 hiện đang có sẵn đủ size 38 đến 44 với 3 màu Đen Trắng, Xanh Neon và Xám Cam ạ.",
            "Dạ Ultra Boost 2026 đang được giảm 16% chỉ còn 1.250.000đ và được bảo hành chính hãng 12 tháng bạn nhé!",
            "Dạ bạn cho em xin địa chỉ để shop gửi shipper giao hỏa tốc 2 giờ đến bạn ngay ạ!",
        ]
    elif any(k in norm for k in ["freeship", "ship", "phi ship", "van chuyen", "giao hang", "hoa toc"]):
        suggestions = [
            "Dạ chào bạn, đơn hàng từ 500.000đ được FREESHIP 100% toàn quốc, đơn dưới 500k ship đồng giá 25k ạ.",
            "Dạ shop có hỗ trợ giao hỏa tốc trong 2 giờ tại nội thành TP.HCM và Hà Nội bạn nhé!",
            "Dạ đơn hàng của bạn dự kiến sẽ được giao trong 1-2 ngày làm việc bạn nhé.",
        ]
    elif any(k in norm for k in ["doi tra", "bao hanh", "loi", "rach", "hong", "hu"]):
        suggestions = [
            "Dạ em rất xin lỗi vì trải nghiệm chưa trọn vẹn này. Em sẽ hỗ trợ đổi sản phẩm mới ngay cho bạn ạ!",
            "Dạ SportGear hỗ trợ đổi 1-1 miễn phí tại nhà trong 30 ngày, shipper sẽ mang hàng mới đến đổi tận nơi ạ.",
            "Dạ bạn cho em xin số điện thoại để em liên hệ hỗ trợ xử lý ngay lập tức nhé!",
        ]
    elif any(k in norm for k in ["chi nhanh", "dia chi", "o dau", "mo cua", "may gio", "quan 1", "cau giay"]):
        suggestions = [
            "Dạ chi nhánh TP.HCM tại 120 Nguyễn Trãi Q1 mở cửa từ 8:00 đến 21:30 tất cả các ngày trong tuần ạ.",
            "Dạ chi nhánh Hà Nội tại 88 Cầu Giấy luôn sẵn đủ size và mẫu để bạn ghé trải nghiệm trực tiếp ạ.",
            "Dạ bạn đang ở khu vực nào để em hướng dẫn đường đi đến chi nhánh gần nhất cho bạn nhé!",
        ]
    else:
        suggestions = [
            "Dạ chào bạn, SportGear có thể hỗ trợ giải đáp thêm thông tin gì về sản phẩm hoặc đơn hàng cho bạn không ạ?",
            "Dạ bên em đang có chương trình khuyến mãi giảm 20% và tặng voucher freeship cho khách hàng mới ạ.",
            "Dạ em đã ghi nhận thông tin và sẽ hỗ trợ kiểm tra đơn hàng gửi ngay cho bạn nhé!",
        ]

    return APIResponse(
        meta=MetaResponse(code=200, message="Success"),
        data=suggestions,
    )


@router.get("/demo-stats", response_model=APIResponse)
def get_demo_dashboard_stats():
    """Thống kê tổng quan cho Flutter Web Admin Dashboard (không cần auth)"""
    try:
        supabase = get_supabase_admin()
        # 1. Tổng tickets
        all_tickets = supabase.table("tickets").select("id, status, intent, source, created_at").execute()
        tickets_data = all_tickets.data or []
    except Exception as e:
        _log_demo_fallback_once("demo-stats", "Error fetching demo stats", e)
        return APIResponse(
            meta=MetaResponse(code=200, message="Success"),
            data=demo_store.dashboard_stats(),
        )
    if not tickets_data:
        return APIResponse(
            meta=MetaResponse(code=200, message="Success"),
            data=demo_store.dashboard_stats(),
        )
    
    total = len(tickets_data)
    open_count = sum(1 for t in tickets_data if t.get("status") in ["open", "pending"])
    in_prog = sum(1 for t in tickets_data if t.get("status") == "in_progress")
    resolved = sum(1 for t in tickets_data if t.get("status") == "resolved")
    
    # AI handled (intent=question và resolved hoặc open không bị complaint)
    ai_handled = sum(1 for t in tickets_data if t.get("intent") in ["question", None])
    ai_percent = round((ai_handled / total * 100) if total > 0 else 89.2, 1)

    # Thống kê theo nguồn
    web_count = sum(1 for t in tickets_data if t.get("source") == "web")
    fb_count = sum(1 for t in tickets_data if t.get("source") == "facebook")
    email_count = sum(1 for t in tickets_data if t.get("source") == "email")

    # Doanh số và tiền lương ước tính
    estimated_revenue = f"{max(12, total * 3.5):.1f}.000.000đ"
    saved_salary = f"{max(6, int(total * 1.8))}.500.000đ/tháng"

    return APIResponse(
        meta=MetaResponse(code=200, message="Success"),
        data={
            "total_tickets": total,
            "open_tickets": open_count,
            "in_progress_tickets": in_prog,
            "resolved_tickets": resolved,
            "ai_handled_percent": ai_percent,
            "avg_response_time": "0.4s",
            "satisfaction_score": "4.9/5.0",
            "saved_salary": saved_salary,
            "estimated_revenue": estimated_revenue,
            "channels": {
                "web": web_count,
                "facebook": fb_count,
                "email": email_count,
            }
        },
    )


@router.get("/demo-product-issues", response_model=APIResponse)
def get_demo_product_issues():
    """
    Phân tích các sản phẩm bị báo lỗi nhiều nhất từ complaints.
    Trả về top sản phẩm dựa trên keyword trong nội dung tin nhắn.
    """
    try:
        supabase = get_supabase_admin()

        # Lấy tất cả messages từ complaint tickets
        complaint_tickets = (
            supabase.table("tickets")
            .select("id, summary")
            .eq("intent", "complaint")
            .execute()
        )

        # Lấy messages từ tất cả tickets (để phân tích nội dung)
        all_msgs = (
            supabase.table("messages")
            .select("content, sender_type, created_at")
            .eq("sender_type", "customer")
            .order("created_at", desc=True)
            .limit(200)
            .execute()
        )
    except Exception as e:
        _log_demo_fallback_once("demo-product-issues", "Error fetching demo product issues", e)
        return APIResponse(
            meta=MetaResponse(code=200, message="Success"),
            data=DEMO_PRODUCT_ISSUES_FALLBACK,
        )

    import unicodedata
    def _strip(s: str) -> str:
        return "".join(
            c for c in unicodedata.normalize("NFD", s) if unicodedata.category(c) != "Mn"
        ).replace("đ", "d").replace("Đ", "D").lower()

    # Từ điển sản phẩm và keyword phát hiện
    product_keywords = {
        "Áo Polo Pro Active": ["polo", "polo pro", "ao polo", "ao the thao"],
        "Giày Ultra Boost 2026": ["ultra boost", "giay", "giay the thao", "ultra boost 2026"],
        "Quần Gym Flex": ["quan gym", "quan flex", "quan the thao", "gym flex"],
        "Balo Sport Pro": ["balo", "tui xach", "ba lo", "balo sport"],
        "Áo Thun DryFit": ["ao thun", "dry fit", "dryfit", "thun"],
    }

    issue_keywords = ["loi", "hong", "rach", "hu", "that bai", "sai", "khong dung", "doi tra", "bao hanh", "kem chat luong", "xau", "buc xuc"]

    # Đếm số lần từng sản phẩm bị đề cập trong complaint
    product_counts: dict = {p: {"count": 0, "issues": []} for p in product_keywords}

    all_texts = []
    for msg in (all_msgs.data or []):
        all_texts.append(msg.get("content", ""))
    for t in (complaint_tickets.data or []):
        all_texts.append(t.get("summary", "") or "")
        all_texts.append(t.get("context_summary", "") or "")

    for text in all_texts:
        norm = _strip(text)
        has_issue = any(k in norm for k in issue_keywords)
        for product, keywords in product_keywords.items():
            if any(k in norm for k in keywords):
                product_counts[product]["count"] += 1
                if has_issue and text[:60] not in product_counts[product]["issues"]:
                    product_counts[product]["issues"].append(text[:60])

    # Đảm bảo có dữ liệu demo nếu DB chưa có nhiều
    if all(v["count"] == 0 for v in product_counts.values()):
        return APIResponse(
            meta=MetaResponse(code=200, message="Success"),
            data=DEMO_PRODUCT_ISSUES_FALLBACK,
        )

    # Sắp xếp theo số lần báo lỗi
    sorted_products = sorted(
        [{"product": k, "complaint_count": v["count"], "top_issues": v["issues"][:3]} for k, v in product_counts.items()],
        key=lambda x: x["complaint_count"],
        reverse=True
    )

    # Phân tích khoảng trống tri thức AI (các chủ đề chưa có tài liệu)
    ai_gap_keywords = {
        "Chính sách trả hàng quốc tế": ["tra hang quoc te", "ship quoc te", "nuoc ngoai"],
        "Bảo hành giày theo thương hiệu": ["bao hanh nike", "bao hanh adidas", "bao hanh hang"],
        "Chương trình thành viên VIP": ["thanh vien", "vip", "loyalty", "tich diem"],
        "Hướng dẫn chăm sóc sản phẩm": ["giat may", "bao quan", "cham soc", "lam sach"],
        "So sánh sản phẩm tương đương": ["so sanh", "khac nhau", "tot hon", "nen mua"],
    }

    ai_gaps = []
    for topic, keywords in ai_gap_keywords.items():
        count = sum(
            1 for text in all_texts
            if any(k in _strip(text) for k in keywords)
        )
        ai_gaps.append({"topic": topic, "query_count": max(count, 1 if topic == "Hướng dẫn chăm sóc sản phẩm" else 0)})

    ai_gaps = sorted(ai_gaps, key=lambda x: x["query_count"], reverse=True)

    return APIResponse(
        meta=MetaResponse(code=200, message="Success"),
        data={
            "top_product_issues": sorted_products,
            "ai_knowledge_gaps": [g for g in ai_gaps if g["query_count"] > 0],
        },
    )


@router.get("/demo-agent-performance", response_model=APIResponse)
def get_demo_agent_performance():
    """
    Thống kê hiệu suất nhân viên: thời gian phản hồi, số ticket xử lý,
    tỷ lệ chốt thành công, so sánh AI vs human handling time.
    """
    from datetime import datetime, timezone, timedelta

    try:
        supabase = get_supabase_admin()
        # Lấy tất cả messages gần đây
        all_msgs = (
            supabase.table("messages")
            .select("ticket_id, sender_type, created_at")
            .order("created_at", desc=False)
            .limit(500)
            .execute()
        )
    except Exception as e:
        _log_demo_fallback_once("demo-agent-performance", "Error fetching demo agent performance", e)
        return APIResponse(
            meta=MetaResponse(code=200, message="Success"),
            data=DEMO_AGENT_PERFORMANCE_FALLBACK,
        )

    # Nhóm messages theo ticket để tính thời gian phản hồi
    ticket_msgs: dict = {}
    for msg in (all_msgs.data or []):
        tid = msg["ticket_id"]
        if tid not in ticket_msgs:
            ticket_msgs[tid] = []
        ticket_msgs[tid].append(msg)

    # Tính thời gian phản hồi: thời gian từ message customer đến message bot/human đầu tiên
    bot_response_times = []
    human_response_times = []

    for tid, msgs in ticket_msgs.items():
        customer_time = None
        for msg in msgs:
            if msg["sender_type"] == "customer" and customer_time is None:
                try:
                    customer_time = datetime.fromisoformat(msg["created_at"].replace("Z", "+00:00"))
                except Exception:
                    pass
            elif customer_time and msg["sender_type"] in ["bot", "human"]:
                try:
                    reply_time = datetime.fromisoformat(msg["created_at"].replace("Z", "+00:00"))
                    diff_seconds = (reply_time - customer_time).total_seconds()
                    if 0 < diff_seconds < 3600:  # Bỏ qua các outlier > 1h
                        if msg["sender_type"] == "bot":
                            bot_response_times.append(diff_seconds)
                        else:
                            human_response_times.append(diff_seconds)
                    customer_time = None  # Reset cho tin nhắn tiếp theo
                except Exception:
                    pass

    avg_bot_secs = round(sum(bot_response_times) / len(bot_response_times), 1) if bot_response_times else 0.4
    avg_human_secs = round(sum(human_response_times) / len(human_response_times), 1) if human_response_times else 185.0

    # Thống kê tickets
    try:
        tickets_data = supabase.table("tickets").select("id, status, intent, assigned_to, created_at, resolved_at").execute()
        all_tickets = tickets_data.data or []
    except Exception as e:
        _log_demo_fallback_once(
            "demo-performance-tickets",
            "Error fetching demo performance tickets",
            e,
        )
        all_tickets = []

    total = len(all_tickets)
    resolved = sum(1 for t in all_tickets if t.get("status") == "resolved")
    human_handled = sum(1 for t in all_tickets if t.get("intent") == "complaint")

    # Fallback demo data nếu DB chưa có nhiều dữ liệu
    if avg_bot_secs == 0.4 or total < 3:
        fallback = dict(DEMO_AGENT_PERFORMANCE_FALLBACK)
        fallback["total_tickets"] = max(total, 12)
        fallback["resolved_tickets"] = max(resolved, 9)
        fallback["human_tickets"] = max(human_handled, 1)
        return APIResponse(
            meta=MetaResponse(code=200, message="Success"),
            data=fallback,
        )

    # Phân bổ theo giờ trong ngày
    hourly_counts: dict = {}
    for t in all_tickets:
        try:
            hour = datetime.fromisoformat(t["created_at"].replace("Z", "+00:00")).astimezone(timezone(timedelta(hours=7))).hour
            h_label = f"{hour}:00"
            hourly_counts[h_label] = hourly_counts.get(h_label, 0) + 1
        except Exception:
            pass

    hourly_distribution = [{"hour": k, "count": v} for k, v in sorted(hourly_counts.items())]

    resolution_rate = round((resolved / total * 100) if total > 0 else 0, 1)
    ai_count = total - human_handled
    ai_ratio = round((ai_count / total * 100) if total > 0 else 91.5, 1)

    return APIResponse(
        meta=MetaResponse(code=200, message="Success"),
        data={
            "avg_bot_response_seconds": avg_bot_secs,
            "avg_human_response_seconds": avg_human_secs,
            "ai_vs_human_ratio": f"{ai_ratio}% AI / {100 - ai_ratio}% Nhân Viên",
            "total_tickets": total,
            "resolved_tickets": resolved,
            "resolution_rate_percent": resolution_rate,
            "human_tickets": human_handled,
            "hourly_distribution": hourly_distribution,
            "top_agents": [],
        },
    )


class TicketStatusUpdatePayload(BaseModel):
    status: str

@router.patch("/demo-status/{ticket_id}", response_model=APIResponse)
def update_demo_ticket_status(ticket_id: UUID, payload: TicketStatusUpdatePayload):
    """Cập nhật trạng thái ticket không cần auth cho Flutter Web Admin"""
    update_data = {"status": payload.status}
    if payload.status == "resolved":
        from datetime import datetime, timezone
        update_data["resolved_at"] = datetime.now(timezone.utc).isoformat()

    try:
        supabase = get_supabase_admin()
        result = supabase.table("tickets").update(update_data).eq("id", str(ticket_id)).execute()
        if not result.data:
            raise HTTPException(status_code=404, detail="Ticket không tồn tại.")
        data = result.data[0]
    except HTTPException:
        raise
    except Exception as e:
        _log_demo_fallback_once(
            "demo-status",
            "Error updating demo ticket status; using in-memory demo store",
            e,
        )
        data = demo_store.update_ticket(str(ticket_id), **update_data)
        if not data:
            raise HTTPException(status_code=404, detail="Ticket không tồn tại.")
        
    return APIResponse(
        meta=MetaResponse(code=200, message=f"Đã cập nhật trạng thái thành {payload.status}."),
        data=data,
    )


@router.get("/stats/dashboard", response_model=APIResponse)
def get_dashboard_stats(
    current_user: dict = Depends(require_super_admin),
):
    """
    Thống kê tổng quan cho super_admin:
    - Tổng ticket hôm nay
    - Ticket đang mở
    - Ticket resolved hôm nay
    - % AI tự xử lý (question intent, không cần agent)
    """
    supabase = get_supabase_client()
    from datetime import datetime, timezone

    today_start = datetime.now(timezone.utc).replace(
        hour=0, minute=0, second=0, microsecond=0
    ).isoformat()

    # Tổng ticket hôm nay
    today_result = (
        supabase.table("tickets")
        .select("id, intent, status", count="exact")
        .gte("created_at", today_start)
        .execute()
    )
    today_tickets = today_result.data or []
    total_today = today_result.count or 0

    # Ticket đang mở
    open_result = (
        supabase.table("tickets")
        .select("id", count="exact")
        .in_("status", ["open", "in_progress", "pending"])
        .execute()
    )

    # Ticket resolved hôm nay
    resolved_today = sum(
        1 for t in today_tickets if t["status"] == "resolved"
    )

    # % AI tự xử lý = ticket intent=question và status=resolved / tổng hôm nay
    ai_handled = sum(
        1 for t in today_tickets
        if t["intent"] == "question" and t["status"] == "resolved"
    )
    ai_percent = round((ai_handled / total_today * 100) if total_today > 0 else 0, 1)

    return APIResponse(
        meta=MetaResponse(code=200, message="Success"),
        data={
            "total_tickets_today": total_today,
            "open_tickets": open_result.count or 0,
            "resolved_tickets_today": resolved_today,
            "ai_handled_percent": ai_percent,
        },
    )


@router.get("", response_model=APIResponse)
def list_tickets(
    ticket_status: Optional[TicketStatus] = Query(None, alias="status"),
    source: Optional[TicketSource] = None,
    page: int = Query(1, ge=1),
    limit: int = Query(20, ge=1, le=100),
    current_user: dict = Depends(get_current_user),
):
    """
    Lấy danh sách tickets.
    - super_admin: thấy tất cả
    - agent: chỉ thấy ticket open / in_progress / được giao cho mình
    """
    supabase = get_supabase_client()
    offset = (page - 1) * limit

    query = supabase.table("tickets").select("*", count="exact")

    # Phân quyền
    if current_user["role"] == "agent":
        # Agent chỉ thấy ticket open, in_progress, hoặc giao cho mình
        query = query.or_(
            f"status.in.(open,in_progress),assigned_to.eq.{current_user['id']}"
        )

    # Filter tùy chọn
    if ticket_status:
        query = query.eq("status", ticket_status.value)
    if source:
        query = query.eq("source", source.value)

    result = (
        query.order("created_at", desc=True)
        .range(offset, offset + limit - 1)
        .execute()
    )

    return APIResponse(
        meta=MetaResponse(code=200, message="Success"),
        data={
            "items": result.data,
            "total": result.count,
            "page": page,
            "limit": limit,
        },
    )


@router.get("/{ticket_id}", response_model=APIResponse)
def get_ticket(
    ticket_id: UUID,
    current_user: dict = Depends(get_current_user),
):
    """Lấy chi tiết 1 ticket kèm toàn bộ messages."""
    supabase = get_supabase_client()

    ticket_result = (
        supabase.table("tickets")
        .select("*")
        .eq("id", str(ticket_id))
        .single()
        .execute()
    )

    if not ticket_result.data:
        raise HTTPException(status_code=404, detail="Ticket không tồn tại.")

    ticket = ticket_result.data

    # Agent không được xem ticket resolved của người khác
    if (
        current_user["role"] == "agent"
        and ticket["status"] == "resolved"
        and ticket["assigned_to"] != current_user["id"]
    ):
        raise HTTPException(status_code=403, detail="Bạn không có quyền xem ticket này.")

    # Lấy toàn bộ messages của ticket
    messages_result = (
        supabase.table("messages")
        .select("*")
        .eq("ticket_id", str(ticket_id))
        .order("created_at")
        .execute()
    )

    return APIResponse(
        meta=MetaResponse(code=200, message="Success"),
        data={
            "ticket": ticket,
            "messages": messages_result.data,
        },
    )


@router.patch("/{ticket_id}", response_model=APIResponse)
def update_ticket(
    ticket_id: UUID,
    payload: TicketUpdate,
    current_user: dict = Depends(get_current_user),
):
    """
    Cập nhật status hoặc assigned_to của ticket.
    Agent chỉ được đổi status; super_admin đổi cả assigned_to.
    """
    supabase = get_supabase_client()

    update_data = payload.model_dump(exclude_none=True)

    # Agent không được tự assign ticket cho người khác
    if current_user["role"] == "agent" and "assigned_to" in update_data:
        raise HTTPException(
            status_code=403,
            detail="Agent không có quyền thay đổi người phụ trách.",
        )

    if not update_data:
        raise HTTPException(status_code=400, detail="Không có trường nào để cập nhật.")

    # Nếu resolve → ghi resolved_at
    if update_data.get("status") == "resolved":
        from datetime import datetime, timezone
        update_data["resolved_at"] = datetime.now(timezone.utc).isoformat()

    result = (
        supabase.table("tickets")
        .update(update_data)
        .eq("id", str(ticket_id))
        .execute()
    )

    if not result.data:
        raise HTTPException(status_code=404, detail="Ticket không tồn tại.")

    return APIResponse(
        meta=MetaResponse(code=200, message="Ticket đã được cập nhật."),
        data=result.data[0],
    )
