from enum import StrEnum


class IntentType(StrEnum):
    QUESTION = "question"
    COMPLAINT = "complaint"
    SPAM = "spam"


class DocumentFileType(StrEnum):
    PDF = "pdf"
    DOCX = "docx"
    TXT = "txt"


class EmbeddingStatus(StrEnum):
    PROCESSING = "processing"
    READY = "ready"
    ERROR = "error"
