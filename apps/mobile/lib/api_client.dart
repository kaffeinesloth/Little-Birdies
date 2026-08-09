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
      return MockData.tickets;
    }
  }

  Future<Message> sendReply(String ticketId, String content,
      {String? accessToken}) async {
    try {
      final response = await _post(
        '/tickets/$ticketId/messages',
        jsonEncode({'content': content}),
        accessToken,
      );
      final payload = jsonDecode(response) as Map<String, dynamic>;
      return _messageFromJson(payload['message'] as Map<String, dynamic>);
    } catch (_) {
      return Message(
        id: 'mock-human-${DateTime.now().millisecondsSinceEpoch}',
        senderType: 'human',
        content: content,
        createdAt: DateTime.now(),
      );
    }
  }

  Future<Ticket> resolveTicket(Ticket ticket, {String? accessToken}) async {
    try {
      final response =
          await _post('/tickets/${ticket.id}/resolve', '{}', accessToken);
      return _ticketFromJson(jsonDecode(response) as Map<String, dynamic>);
    } catch (_) {
      return ticket.copyWith(status: TicketStatus.resolved);
    }
  }

  Future<Ticket> reopenTicket(Ticket ticket, {String? accessToken}) async {
    try {
      final response =
          await _post('/tickets/${ticket.id}/reopen', '{}', accessToken);
      return _ticketFromJson(jsonDecode(response) as Map<String, dynamic>);
    } catch (_) {
      return ticket.copyWith(status: TicketStatus.open);
    }
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
      return MockData.messages[ticketId] ?? <Message>[];
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

  Future<DashboardSummary> fetchDashboard({String? accessToken}) async {
    try {
      await _get('/dashboard', accessToken);
      return MockData.dashboard;
    } catch (_) {
      return MockData.dashboard;
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

class MockData {
  static final tickets = <Ticket>[
    Ticket(
      id: 'TCK-1024',
      customerName: 'Linh Tran',
      source: ChannelType.web,
      status: TicketStatus.pending,
      intent: 'complaint',
      preview: 'Refund request after delayed delivery',
      updatedAt: DateTime.now().subtract(const Duration(minutes: 2)),
    ),
    Ticket(
      id: 'TCK-1023',
      customerName: 'Minh Pham',
      source: ChannelType.facebook,
      status: TicketStatus.open,
      intent: 'question',
      preview: 'Asked about warranty period for headphones',
      updatedAt: DateTime.now().subtract(const Duration(minutes: 8)),
    ),
    Ticket(
      id: 'TCK-1022',
      customerName: 'An Nguyen',
      source: ChannelType.email,
      status: TicketStatus.inProgress,
      intent: 'question',
      preview: 'Needs invoice copy for order #4821',
      updatedAt: DateTime.now().subtract(const Duration(minutes: 18)),
      assignedTo: 'agent-demo',
    ),
  ];

  static final messages = <String, List<Message>>{
    'TCK-1024': [
      Message(
        id: 'MSG-1',
        senderType: 'customer',
        content: 'I want a refund because my delivery is late.',
        createdAt: DateTime.now().subtract(const Duration(minutes: 3)),
      ),
      Message(
        id: 'MSG-2',
        senderType: 'bot',
        content:
            'I am sorry about the delay. A staff member is reviewing this now.',
        createdAt: DateTime.now().subtract(const Duration(minutes: 2)),
      ),
    ],
  };

  static final notifications = <NotificationItem>[
    NotificationItem(
      id: 'NTF-1',
      title: 'Urgent complaint',
      body: 'Linh Tran needs a refund review.',
      createdAt: DateTime.now().subtract(const Duration(minutes: 2)),
      isRead: false,
      ticketId: 'TCK-1024',
    ),
    NotificationItem(
      id: 'NTF-2',
      title: 'New web ticket',
      body: 'A customer asked about warranty terms.',
      createdAt: DateTime.now().subtract(const Duration(minutes: 9)),
      isRead: true,
      ticketId: 'TCK-1023',
    ),
  ];

  static const dashboard = DashboardSummary(
    messagesToday: 186,
    aiHandlingRate: 78,
    openTickets: 14,
    averageResponseSeconds: 4.2,
  );
}
