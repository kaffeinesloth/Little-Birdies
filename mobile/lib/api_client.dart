import 'dart:convert';
import 'dart:io';

import 'models.dart';

class SmartHelpdeskApiClient {
  SmartHelpdeskApiClient({
    String? baseUrl,
  }) : baseUrl = baseUrl ??
            const String.fromEnvironment(
              'API_BASE_URL',
              defaultValue: 'http://localhost:8000',
            );

  final String baseUrl;

  Future<List<Ticket>> fetchTickets({String? accessToken}) async {
    try {
      final response = await _get('/tickets?limit=50&offset=0', accessToken);
      final items = jsonDecode(response) as Map<String, dynamic>;
      return (items['items'] as List<dynamic>? ?? <dynamic>[])
          .map((item) => _ticketFromJson(item as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return <Ticket>[];
    }
  }

  Future<Message> sendReply(String ticketId, String content,
      {String? accessToken}) async {
    final response = await _post(
      '/tickets/$ticketId/messages',
      jsonEncode({'content': content}),
      accessToken,
    );
    final payload = jsonDecode(response) as Map<String, dynamic>;
    return _messageFromJson(payload['message'] as Map<String, dynamic>);
  }

  Future<Ticket> resolveTicket(Ticket ticket, {String? accessToken}) async {
    final response =
        await _post('/tickets/${ticket.id}/resolve', '{}', accessToken);
    return _ticketFromJson(jsonDecode(response) as Map<String, dynamic>);
  }

  Future<Ticket> reopenTicket(Ticket ticket, {String? accessToken}) async {
    final response =
        await _post('/tickets/${ticket.id}/reopen', '{}', accessToken);
    return _ticketFromJson(jsonDecode(response) as Map<String, dynamic>);
  }

  Future<List<Message>> fetchMessages(String ticketId,
      {String? accessToken}) async {
    try {
      final response = await _get('/tickets/$ticketId/messages', accessToken);
      final items = jsonDecode(response) as Map<String, dynamic>;
      return (items['items'] as List<dynamic>? ?? <dynamic>[])
          .map((item) => _messageFromJson(item as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return <Message>[];
    }
  }

  Future<List<NotificationItem>> fetchNotifications(
      {String? accessToken}) async {
    try {
      final response = await _get('/notifications', accessToken);
      final payload = jsonDecode(response) as Map<String, dynamic>;
      return (payload['items'] as List<dynamic>? ?? <dynamic>[])
          .map((item) => _notificationFromJson(item as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return <NotificationItem>[];
    }
  }

  Future<void> updatePresence(PresenceStatus status,
      {String? accessToken}) async {
    try {
      await _post(
        '/presence/status',
        jsonEncode(
            {'status': status == PresenceStatus.online ? 'online' : 'offline'}),
        accessToken,
      );
    } catch (_) {
      return;
    }
  }

  Future<void> sendHeartbeat({String? accessToken}) async {
    try {
      await _post('/presence/heartbeat', '{}', accessToken);
    } catch (_) {
      return;
    }
  }

  Future<void> registerPushToken(String token, {String? accessToken}) async {
    try {
      await _post(
        '/notifications/register-token',
        jsonEncode({'provider': 'fcm', 'token': token}),
        accessToken,
      );
    } catch (_) {
      return;
    }
  }

  Future<String> _get(String path, String? accessToken) async {
    final request = await HttpClient().getUrl(Uri.parse('$baseUrl$path'));
    _applyHeaders(request, accessToken);
    final response = await request.close();
    return _readResponse(response);
  }

  Future<String> _post(String path, String body, String? accessToken) async {
    final request = await HttpClient().postUrl(Uri.parse('$baseUrl$path'));
    _applyHeaders(request, accessToken);
    request.write(body);
    final response = await request.close();
    return _readResponse(response);
  }

  void _applyHeaders(HttpClientRequest request, String? accessToken) {
    request.headers.contentType = ContentType.json;
    if (accessToken != null) {
      request.headers
          .set(HttpHeaders.authorizationHeader, 'Bearer $accessToken');
    }
  }

  Future<String> _readResponse(HttpClientResponse response) async {
    final body = await response.transform(utf8.decoder).join();
    if (response.statusCode >= 400) {
      throw HttpException('API request failed: ${response.statusCode}');
    }
    return body;
  }
}

Ticket _ticketFromJson(Map<String, dynamic> json) {
  return Ticket(
    id: json['id']?.toString() ?? '',
    customerName:
        (json['customer_name'] ?? json['customerName'] ?? 'Unknown customer')
            .toString(),
    source: _channel(json['source']?.toString()),
    status: _ticketStatus(json['status']?.toString()),
    intent: (json['intent'] ?? 'question').toString(),
    preview: (json['summary'] ?? json['last_message_preview'] ?? 'No preview')
        .toString(),
    updatedAt: DateTime.tryParse(
            (json['updated_at'] ?? json['updatedAt'] ?? '').toString()) ??
        DateTime.now(),
    assignedTo: (json['assigned_to'] ?? json['assignedTo'])?.toString(),
  );
}

Message _messageFromJson(Map<String, dynamic> json) {
  return Message(
    id: json['id']?.toString() ?? '',
    senderType:
        (json['sender_type'] ?? json['senderType'] ?? 'customer').toString(),
    content: (json['content'] ?? '').toString(),
    createdAt: DateTime.tryParse(
            (json['created_at'] ?? json['createdAt'] ?? '').toString()) ??
        DateTime.now(),
  );
}

NotificationItem _notificationFromJson(Map<String, dynamic> json) {
  return NotificationItem(
    id: json['id']?.toString() ?? '',
    title: (json['title'] ?? '').toString(),
    body: (json['body'] ?? '').toString(),
    createdAt: DateTime.tryParse(
            (json['created_at'] ?? json['createdAt'] ?? '').toString()) ??
        DateTime.now(),
    isRead: json['is_read'] == true || json['isRead'] == true,
    ticketId: (json['ticket_id'] ?? json['ticketId'])?.toString(),
  );
}

ChannelType _channel(String? value) {
  return switch (value) {
    'facebook' => ChannelType.facebook,
    'email' => ChannelType.email,
    _ => ChannelType.web,
  };
}

TicketStatus _ticketStatus(String? value) {
  return switch (value) {
    'in_progress' => TicketStatus.inProgress,
    'pending' => TicketStatus.pending,
    'resolved' => TicketStatus.resolved,
    _ => TicketStatus.open,
  };
}
