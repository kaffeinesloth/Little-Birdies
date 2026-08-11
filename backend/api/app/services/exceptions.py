class ServiceError(Exception):
    """Base class for service-layer errors."""


class RecordNotFoundError(ServiceError):
    """Raised when a requested database record does not exist."""


class InvalidTicketTransitionError(ServiceError):
    """Raised when a ticket status change violates the workflow."""


class OutboundDeliveryError(ServiceError):
    """Raised when a human reply cannot be delivered to the original channel."""
