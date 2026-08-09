from enum import StrEnum


class UserRole(StrEnum):
    SUPER_ADMIN = "super_admin"
    AGENT = "agent"


class UserStatus(StrEnum):
    ONLINE = "online"
    OFFLINE = "offline"
    DISABLED = "disabled"


class ChannelType(StrEnum):
    WEB = "web"
    FACEBOOK = "facebook"
    EMAIL = "email"


class TicketStatus(StrEnum):
    OPEN = "open"
    IN_PROGRESS = "in_progress"
    PENDING = "pending"
    RESOLVED = "resolved"


class IntentType(StrEnum):
    QUESTION = "question"
    COMPLAINT = "complaint"
    SPAM = "spam"


class SenderType(StrEnum):
    CUSTOMER = "customer"
    BOT = "bot"
    HUMAN = "human"


class DocumentFileType(StrEnum):
    PDF = "pdf"
    DOCX = "docx"
    TXT = "txt"


class EmbeddingStatus(StrEnum):
    PROCESSING = "processing"
    READY = "ready"
    ERROR = "error"
