import os
import re

MAIN_DART = r'mobile/lib/main.dart'

with open(MAIN_DART, 'r', encoding='utf-8') as f:
    content = f.read()

# 1. Add imports
if "package:http/http.dart" not in content:
    content = content.replace(
        "import 'package:supabase_flutter/supabase_flutter.dart';",
        "import 'package:supabase_flutter/supabase_flutter.dart';\nimport 'package:http/http.dart' as http;\nimport 'dart:convert';"
    )

# 2. Make demoTickets mutable
content = content.replace(
    "const demoTickets = [",
    "List<SupportTicket> demoTickets = ["
)

# 3. Inject fetch logic into _WebAdminWorkspaceState
init_state_injection = """
  @override
  void initState() {
    super.initState();
    _fetchTickets();
    _setupRealtime();
  }

  Future<void> _fetchTickets() async {
    try {
      final res = await http.get(Uri.parse('http://localhost:8000/api/v1/tickets'));
      if (res.statusCode == 200) {
        final data = json.decode(res.body)['data'] as List;
        setState(() {
          demoTickets = data.map((e) {
            return SupportTicket(
              number: e['id'].hashCode % 1000,
              customerName: e['customer_name'] ?? 'Khách Hàng',
              source: e['source'] == 'web' ? TicketSource.web : TicketSource.facebook,
              status: _parseStatus(e['status']),
              intent: _parseIntent(e['intent']),
              summary: e['summary'] ?? 'Không có tóm tắt',
              createdAgo: 'Vừa xong',
              ticketId: e['id'],
              messages: [],
            );
          }).toList();
          if (demoTickets.isNotEmpty) {
            _selectedTicket = demoTickets.first;
            _fetchMessages(_selectedTicket.ticketId);
          }
        });
      }
    } catch (e) {
      print('Fetch tickets error: $e');
    }
  }

  TicketStatus _parseStatus(String? s) {
    if (s == 'open') return TicketStatus.open;
    if (s == 'in_progress') return TicketStatus.inProgress;
    if (s == 'resolved') return TicketStatus.resolved;
    return TicketStatus.pending;
  }
  
  TicketIntent _parseIntent(String? s) {
    if (s == 'complaint') return TicketIntent.complaint;
    if (s == 'question') return TicketIntent.question;
    return TicketIntent.question;
  }

  Future<void> _fetchMessages(String ticketId) async {
    try {
      final res = await http.get(Uri.parse('http://localhost:8000/api/v1/tickets/$ticketId/messages'));
      if (res.statusCode == 200) {
        final data = json.decode(res.body)['data'] as List;
        setState(() {
          _liveMessages.clear();
          for (var e in data) {
            _liveMessages.add(TicketMessage(
              sender: e['sender_type'] == 'bot' ? SenderType.bot : 
                     (e['sender_type'] == 'human' ? SenderType.human : SenderType.customer),
              content: e['content'],
            ));
          }
        });
      }
    } catch (e) {
      print('Fetch messages error: $e');
    }
  }

  void _setupRealtime() {
    Supabase.instance.client.channel('public:messages').onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'public',
      table: 'messages',
      callback: (payload) {
        final msg = payload.newRecord;
        if (msg['ticket_id'] == _selectedTicket.ticketId) {
          setState(() {
             _liveMessages.add(TicketMessage(
              sender: msg['sender_type'] == 'bot' ? SenderType.bot : 
                     (msg['sender_type'] == 'human' ? SenderType.human : SenderType.customer),
              content: msg['content'],
            ));
          });
        }
      }
    ).subscribe();
  }
"""

if "_fetchTickets" not in content:
    content = content.replace(
        "class _WebAdminWorkspaceState extends State<WebAdminWorkspace> {",
        "class _WebAdminWorkspaceState extends State<WebAdminWorkspace> {" + init_state_injection
    )

# 4. Modify SupportTicket to hold ticketId
content = content.replace(
    "final List<TicketMessage> messages;",
    "final List<TicketMessage> messages;\n  final String ticketId;"
)
content = content.replace(
    "required this.messages,",
    "required this.messages,\n    this.ticketId = '',"
)

# 5. Fix _sendReply logic to use API
send_reply_injection = """
  void _sendReply() async {
    final text = _replyController.text.trim();
    if (text.isEmpty) return;
    
    // Add locally first
    setState(() {
      _liveMessages.add(TicketMessage(sender: SenderType.human, content: text));
      _replyController.clear();
    });
    
    // Send to API
    try {
      await http.post(
        Uri.parse('http://localhost:8000/api/v1/messages/agent-reply-demo'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'ticket_id': _selectedTicket.ticketId,
          'content': text,
        }),
      );
    } catch (e) {
      print('Send reply error: $e');
    }
  }
"""

# replace the old _sendReply function
content = re.sub(
    r"void _sendReply\(\) \{[\s\S]*?_replyController\.clear\(\);\n    \}\);\n  \}",
    send_reply_injection.strip(),
    content
)

# 6. Change _liveMessages from final to mutable list, so we can clear it
content = content.replace(
    "final List<TicketMessage> _liveMessages = [",
    "List<TicketMessage> _liveMessages = ["
)

# 7. Add onSelectTicket logic to fetch messages
content = content.replace(
    "onSelectTicket: (ticket) =>\n                        setState(() => _selectedTicket = ticket),",
    """onSelectTicket: (ticket) {
                        setState(() => _selectedTicket = ticket);
                        _fetchMessages(ticket.ticketId);
                      },"""
)

with open(MAIN_DART, 'w', encoding='utf-8') as f:
    f.write(content)

print("Done patching flutter API.")
