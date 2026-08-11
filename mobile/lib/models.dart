enum UserRole { superAdmin, agent }

enum PresenceStatus { online, offline }

enum TicketStatus { open, inProgress, pending, resolved }

enum ChannelType { web, facebook, email }

class CurrentUser {
  const CurrentUser({
    required this.id,
    required this.email,
    required this.fullName,
    required this.role,
  });

  final String id;
  final String email;
  final String fullName;
  final UserRole role;
}

class Ticket {
  const Ticket({
    required this.id,
    required this.customerName,
    required this.source,
    required this.status,
    required this.intent,
    required this.preview,
    required this.updatedAt,
    this.assignedTo,
  });

  final String id;
  final String customerName;
  final ChannelType source;
  final TicketStatus status;
  final String intent;
  final String preview;
  final DateTime updatedAt;
  final String? assignedTo;

  Ticket copyWith({
    TicketStatus? status,
    String? preview,
    DateTime? updatedAt,
    String? assignedTo,
  }) {
    return Ticket(
      id: id,
      customerName: customerName,
      source: source,
      status: status ?? this.status,
      intent: intent,
      preview: preview ?? this.preview,
      updatedAt: updatedAt ?? this.updatedAt,
      assignedTo: assignedTo ?? this.assignedTo,
    );
  }
}

class Message {
  const Message({
    required this.id,
    required this.senderType,
    required this.content,
    required this.createdAt,
  });

  final String id;
  final String senderType;
  final String content;
  final DateTime createdAt;
}

class NotificationItem {
  const NotificationItem({
    required this.id,
    required this.title,
    required this.body,
    required this.createdAt,
    required this.isRead,
    this.ticketId,
  });

  final String id;
  final String title;
  final String body;
  final DateTime createdAt;
  final bool isRead;
  final String? ticketId;
}
