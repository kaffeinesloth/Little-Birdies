from dataclasses import dataclass
from typing import Any

from app.schemas.common import ChannelType, IntentType, SenderType, TicketStatus
from app.schemas.messages import MessageCreate
from app.schemas.tickets import TicketCreate, TicketUpdate
from app.services.ai_client import AIProcessingError, AIProcessor, ai_timeout_fallback
from app.services.messages import MessageService
from app.services.notifications import NotificationService
from app.services.supabase_table import SupabaseClient
from app.services.tickets import TicketService


@dataclass(frozen=True)
class InboundProcessingResult:
    ticket: dict[str, Any]
    customer_message: dict[str, Any]
    bot_message: dict[str, Any] | None
    notifications: list[dict[str, Any]]
    action: str
    intent: IntentType


class InboundOrchestrator:
    def __init__(self, client: SupabaseClient, ai_processor: AIProcessor) -> None:
        self.client = client
        self.ai_processor = ai_processor
        self.tickets = TicketService(client)
        self.messages = MessageService(client)
        self.notifications = NotificationService(client)

    def process_inbound_message(
        self,
        source: ChannelType | str,
        sender_id: str,
        content: str,
        customer_name: str | None = None,
    ) -> InboundProcessingResult:
        channel = ChannelType(source)
        ticket = self.tickets.find_open_or_pending_ticket(sender_id, channel)
        if ticket is None:
            ticket = self.tickets.create_ticket(
                TicketCreate(
                    customer_id=sender_id,
                    customer_name=customer_name,
                    source=channel,
                )
            )

        customer_message = self.messages.create_message(
            MessageCreate(
                ticket_id=ticket["id"],
                sender_type=SenderType.CUSTOMER,
                sender_id=sender_id,
                content=content,
            )
        )

        try:
            ai_result = self.ai_processor.process_message(
                source=channel.value,
                sender_id=sender_id,
                content=content,
            )
        except AIProcessingError:
            ai_result = ai_timeout_fallback()

        bot_message = None
        notifications: list[dict[str, Any]] = []

        if ai_result.intent == IntentType.SPAM:
            ticket = self.tickets.update_ticket(
                ticket["id"],
                TicketUpdate(intent=IntentType.SPAM, status=TicketStatus.RESOLVED),
            )
            return InboundProcessingResult(
                ticket=ticket,
                customer_message=customer_message,
                bot_message=None,
                notifications=[],
                action="ignored_spam",
                intent=ai_result.intent,
            )

        if ai_result.answer:
            bot_message = self.messages.create_message(
                MessageCreate(
                    ticket_id=ticket["id"],
                    sender_type=SenderType.BOT,
                    sender_id="ai-bot",
                    content=ai_result.answer,
                )
            )

        if ai_result.should_escalate or ai_result.intent == IntentType.COMPLAINT:
            ticket = self.tickets.update_ticket(
                ticket["id"],
                TicketUpdate(
                    intent=ai_result.intent,
                    status=TicketStatus.PENDING,
                    summary=ai_result.reason or content[:160],
                ),
            )
            notifications = self.notifications.create_for_online_agents(
                ticket_id=ticket["id"],
                title="Urgent support ticket",
                body=f"{customer_name or sender_id}: {content[:120]}",
            )
            action = "escalated"
        else:
            ticket = self.tickets.update_ticket(
                ticket["id"],
                TicketUpdate(intent=ai_result.intent, status=TicketStatus.OPEN),
            )
            action = "auto_replied" if bot_message else "recorded"

        return InboundProcessingResult(
            ticket=ticket,
            customer_message=customer_message,
            bot_message=bot_message,
            notifications=notifications,
            action=action,
            intent=ai_result.intent,
        )


def process_inbound_message(
    client: SupabaseClient,
    ai_processor: AIProcessor,
    source: ChannelType | str,
    sender_id: str,
    content: str,
    customer_name: str | None = None,
) -> InboundProcessingResult:
    return InboundOrchestrator(client, ai_processor).process_inbound_message(
        source=source,
        sender_id=sender_id,
        content=content,
        customer_name=customer_name,
    )
