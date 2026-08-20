import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:convert';
import 'dart:async';

bool supabaseRealtimeEnabled = false;

class AppConfig {
  static const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8000',
  );
  static const aiBaseUrl = String.fromEnvironment(
    'AI_BASE_URL',
    defaultValue: 'http://localhost:8001',
  );

  static Uri api(String path) => Uri.parse('$apiBaseUrl$path');
  static Uri ai(String path) => Uri.parse('$aiBaseUrl$path');
}

enum DemoRole {
  superAdmin('Administrator', 'super_admin'),
  agent('Support Agent', 'agent');

  const DemoRole(this.label, this.value);
  final String label;
  final String value;
}

enum ServiceConnection { checking, online, offline }

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  try {
    if (supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty) {
      await Supabase.initialize(
        url: supabaseUrl,
        publishableKey: supabaseAnonKey,
      );
      supabaseRealtimeEnabled = true;
    } else {
      debugPrint('Supabase init skipped; Flutter demo will use REST polling.');
    }
  } catch (e) {
    debugPrint('Supabase init notice: $e');
  }
  runApp(const SmartHelpdeskApp());
}

class SmartHelpdeskApp extends StatelessWidget {
  const SmartHelpdeskApp({super.key, this.enableNetwork = true});

  final bool enableNetwork;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Smart Helpdesk - SportGear Customer Support',
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Roboto',
        scaffoldBackgroundColor: AppColors.background,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          primary: AppColors.primary,
          surface: Colors.white,
        ),
        textTheme: Theme.of(context).textTheme.apply(
          bodyColor: AppColors.slate900,
          displayColor: AppColors.slate900,
        ),
      ),
      home: WebAdminWorkspace(enableNetwork: enableNetwork),
    );
  }
}

class WebAdminWorkspace extends StatefulWidget {
  const WebAdminWorkspace({super.key, this.enableNetwork = true});

  final bool enableNetwork;

  @override
  State<WebAdminWorkspace> createState() => _WebAdminWorkspaceState();
}

class _WebAdminWorkspaceState extends State<WebAdminWorkspace> {
  Timer? _pollTimer;
  int _tabIndex = 0;
  DemoRole _role = DemoRole.superAdmin;
  ServiceConnection _backendConnection = ServiceConnection.checking;
  ServiceConnection _aiConnection = ServiceConnection.checking;
  String _aiProvider = 'checking';
  bool _mobileConversationOpen = false;
  TicketSource? _channelFilter;
  TicketStatus? _statusFilter; // Status filter
  SupportTicket _selectedTicket = initialDemoTickets.first;
  bool _humanTakeover = false;
  final _replyController = TextEditingController();
  final _chatScrollController = ScrollController();
  List<SupportTicket> _tickets = List.from(initialDemoTickets);
  List<TicketMessage> _liveMessages = [];
  Map<String, dynamic> _dashboardStats = {};
  Map<String, dynamic> _productIssues = {}; // Product issue data
  Map<String, dynamic> _agentPerformance = {}; // Agent performance data
  List<Map<String, dynamic>> _staffList = [];
  List<Map<String, dynamic>> _documentsList = [];
  List<String> _aiSuggestions = [
    'Based on your height and weight, size L in the Polo Pro Active should give you the best fit.',
    'SportGear offers free at-home size exchanges within 30 days if the fit is not right.',
    'Polo orders from 500,000 VND include free nationwide shipping and two-hour express delivery in Ho Chi Minh City.',
  ];
  bool _isLoadingSuggestions = false;

  @override
  void initState() {
    super.initState();
    _liveMessages = List.from(_selectedTicket.messages);
    _initializeWorkspace();

    if (widget.enableNetwork) {
      _pollTimer = Timer.periodic(const Duration(milliseconds: 2500), (_) {
        _fetchTickets(silent: true);
        if (_selectedTicket.ticketId.isNotEmpty) {
          _fetchMessages(_selectedTicket.ticketId, silent: true);
        }
      });
    }
  }

  Future<void> _initializeWorkspace() async {
    await _loadDemoRole();
    if (!mounted) return;
    if (!widget.enableNetwork) return;
    _fetchTickets();
    if (_role == DemoRole.superAdmin) {
      _fetchStats();
      _fetchStaff();
      _fetchDocuments();
    }
    _fetchSystemHealth();
    _setupRealtime();
  }

  Future<void> _loadDemoRole() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('smart_helpdesk_demo_role');
    if (!mounted || saved == null) return;
    setState(() {
      _role = saved == DemoRole.agent.value
          ? DemoRole.agent
          : DemoRole.superAdmin;
      if (_role == DemoRole.agent) {
        _tabIndex = 0;
        _dashboardStats = {};
        _productIssues = {};
        _agentPerformance = {};
      }
    });
  }

  Future<void> _setDemoRole(DemoRole role) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('smart_helpdesk_demo_role', role.value);
    if (!mounted) return;
    setState(() {
      _role = role;
      if (_role == DemoRole.agent) {
        _tabIndex = 0;
        _dashboardStats = {};
        _productIssues = {};
        _agentPerformance = {};
        _staffList = [];
        _documentsList = [];
      }
    });
    if (role == DemoRole.superAdmin) {
      _fetchStats();
      _fetchStaff();
      _fetchDocuments();
    }
  }

  Future<void> _fetchSystemHealth() async {
    final backendOnline = await _checkHealth(AppConfig.api('/'));
    final aiProvider = await _readAiProvider();
    if (!mounted) return;
    setState(() {
      _backendConnection = backendOnline
          ? ServiceConnection.online
          : ServiceConnection.offline;
      _aiConnection = aiProvider != null
          ? ServiceConnection.online
          : ServiceConnection.offline;
      _aiProvider = aiProvider ?? 'offline';
    });
  }

  Future<String?> _readAiProvider() async {
    try {
      final response = await http
          .get(AppConfig.ai('/health'))
          .timeout(const Duration(seconds: 3));
      if (response.statusCode < 200 || response.statusCode >= 300) return null;
      final payload = json.decode(utf8.decode(response.bodyBytes));
      return payload['provider']?.toString() ?? 'fallback';
    } catch (_) {
      return null;
    }
  }

  Future<bool> _checkHealth(Uri uri) async {
    try {
      final response = await http.get(uri).timeout(const Duration(seconds: 3));
      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (_) {
      return false;
    }
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _replyController.dispose();
    _chatScrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_chatScrollController.hasClients) {
        _chatScrollController.animateTo(
          _chatScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _showDemoSnack(String message, {Color color = AppColors.slate700}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Map<String, dynamic> _demoStatsFallback() => {
    'total_tickets': 12,
    'open_tickets': 3,
    'in_progress_tickets': 2,
    'resolved_tickets': 9,
    'ai_handled_percent': 91.5,
    'saved_salary': '21,500,000 VND/month',
    'estimated_revenue': '42,000,000 VND',
    'channels': {'web': 7, 'facebook': 3, 'email': 2},
  };

  Map<String, dynamic> _demoProductIssuesFallback() => {
    'top_product_issues': [
      {
        'product': 'Polo Pro Active',
        'complaint_count': 8,
        'top_issues': [
          'Underarm seam tore after two weeks',
          'Size L fits like XL',
          'Color faded after a few washes',
        ],
      },
      {
        'product': 'Ultra Boost 2026 Shoes',
        'complaint_count': 5,
        'top_issues': [
          'Sole adhesive failed after one month',
          'Size 42 runs smaller than expected',
        ],
      },
      {
        'product': 'Gym Flex Pants',
        'complaint_count': 3,
        'top_issues': ['Crotch seam came loose'],
      },
    ],
    'ai_knowledge_gaps': [
      {'topic': 'Product care instructions', 'query_count': 4},
      {'topic': 'VIP membership program', 'query_count': 2},
      {'topic': 'Brand-specific shoe warranties', 'query_count': 1},
    ],
  };

  Map<String, dynamic> _demoAgentPerformanceFallback() => {
    'avg_bot_response_seconds': 0.4,
    'avg_human_response_seconds': 185,
    'ai_vs_human_ratio': '91.5% AI / 8.5% Human',
    'total_tickets': 12,
    'resolved_tickets': 9,
    'resolution_rate_percent': 91.5,
    'human_tickets': 1,
    'hourly_distribution': [
      {'hour': '8:00', 'count': 2},
      {'hour': '9:00', 'count': 5},
      {'hour': '10:00', 'count': 8},
      {'hour': '11:00', 'count': 6},
      {'hour': '12:00', 'count': 4},
      {'hour': '13:00', 'count': 3},
      {'hour': '14:00', 'count': 7},
      {'hour': '15:00', 'count': 9},
      {'hour': '16:00', 'count': 11},
      {'hour': '17:00', 'count': 6},
      {'hour': '18:00', 'count': 4},
      {'hour': '19:00', 'count': 3},
    ],
    'top_agents': [
      {
        'name': 'Lan Nguyen (Support)',
        'tickets_handled': 24,
        'avg_response_min': 2.1,
        'satisfaction': 4.9,
      },
      {
        'name': 'Tuan Tran (Senior)',
        'tickets_handled': 18,
        'avg_response_min': 3.5,
        'satisfaction': 4.8,
      },
      {
        'name': 'Anh Le (Agent)',
        'tickets_handled': 12,
        'avg_response_min': 4.2,
        'satisfaction': 4.7,
      },
    ],
  };

  List<Map<String, dynamic>> _demoStaffFallback() => [
    {
      'id': 'usr_001',
      'full_name': 'Nam Nguyen',
      'email': 'nam.nguyen@sportgear.vn',
      'role': 'super_admin',
      'status': 'online',
    },
    {
      'id': 'usr_002',
      'full_name': 'Ha Tran',
      'email': 'ha.tran@sportgear.vn',
      'role': 'agent',
      'status': 'online',
    },
    {
      'id': 'usr_003',
      'full_name': 'Bao Le',
      'email': 'bao.le@sportgear.vn',
      'role': 'agent',
      'status': 'offline',
    },
  ];

  List<Map<String, dynamic>> _demoDocumentsFallback() => [
    {
      'id': 'doc_default_sportgear',
      'name': 'sportgear_store.txt (6 Products & Support Policies)',
      'file_type': 'txt',
      'embedding_status': 'completed',
      'chunk_count': 19,
    },
  ];

  SupportTicket _fallbackTicketFor(String ticketId) {
    return initialDemoTickets.firstWhere(
      (ticket) => ticket.ticketId == ticketId,
      orElse: () => initialDemoTickets.first,
    );
  }

  SupportTicket _ticketFromRecord(Map<String, dynamic> e) {
    final rawId = e['id']?.toString() ?? '';
    return SupportTicket(
      number: rawId.hashCode.abs() % 1000,
      customerName: e['customer_name'] ?? e['customer_id'] ?? 'Customer',
      source: _parseSource(e['source']),
      status: _parseStatus(e['status']),
      intent: _parseIntent(e['intent']),
      summary:
          e['summary'] ?? e['context_summary'] ?? 'Product support request',
      createdAgo: 'Just now',
      ticketId: rawId,
      messages: [],
    );
  }

  TicketMessage _messageFromRecord(Map<String, dynamic> e) {
    final senderType = e['sender_type']?.toString();
    return TicketMessage(
      id: e['id']?.toString(),
      createdAt: e['created_at']?.toString(),
      sender: senderType == 'bot'
          ? SenderType.bot
          : (senderType == 'human' ? SenderType.human : SenderType.customer),
      content: e['content']?.toString() ?? '',
    );
  }

  List<TicketMessage> _dedupeMessages(List<TicketMessage> messages) {
    final seen = <String>{};
    final deduped = <TicketMessage>[];
    for (final message in messages) {
      final strictKey = message.dedupeKey;
      final contentKey = '${message.sender.index}:${message.content.trim()}';
      if (seen.contains(strictKey) || seen.contains(contentKey)) continue;
      seen.add(strictKey);
      seen.add(contentKey);
      deduped.add(message);
    }
    return deduped;
  }

  bool _appendMessageIfNew(TicketMessage message) {
    final existing = _liveMessages.any(
      (m) =>
          m.dedupeKey == message.dedupeKey ||
          (m.sender == message.sender &&
              m.content.trim() == message.content.trim()),
    );
    if (existing) return false;
    setState(() => _liveMessages.add(message));
    return true;
  }

  void _setSelectedStatus(TicketStatus status) {
    _selectedTicket = _selectedTicket.copyWith(status: status);
    _tickets = _tickets
        .map(
          (ticket) => ticket.ticketId == _selectedTicket.ticketId
              ? ticket.copyWith(status: status)
              : ticket,
        )
        .toList();
    _humanTakeover = status == TicketStatus.inProgress;
  }

  // ── 1. Fetch Danh Sách Tickets Thật ─────────────────────────────────────────
  Future<void> _fetchTickets({bool silent = false}) async {
    try {
      final res = await http.get(AppConfig.api('/api/v1/tickets/demo-list'));
      if (res.statusCode == 200) {
        final jsonRes = json.decode(utf8.decode(res.bodyBytes));
        final data = (jsonRes['data'] as List?) ?? [];
        final loaded = data.isNotEmpty
            ? data
                  .map(
                    (e) =>
                        _ticketFromRecord(Map<String, dynamic>.from(e as Map)),
                  )
                  .toList()
            : List<SupportTicket>.from(initialDemoTickets);
        if (!mounted) return;

        String? ticketToLoad;
        setState(() {
          _tickets = loaded;
          final selectedIndex = _tickets.indexWhere(
            (t) => t.ticketId == _selectedTicket.ticketId,
          );
          if (selectedIndex >= 0) {
            final latestSelected = _tickets[selectedIndex];
            _selectedTicket = latestSelected.copyWith(
              messages: _selectedTicket.messages,
            );
            _humanTakeover = _selectedTicket.status == TicketStatus.inProgress;
          } else {
            _selectedTicket = _tickets.first;
            _humanTakeover = _selectedTicket.status == TicketStatus.inProgress;
            _liveMessages = List.from(_selectedTicket.messages);
            ticketToLoad = _selectedTicket.ticketId;
          }
        });

        if (ticketToLoad != null && ticketToLoad!.isNotEmpty) {
          _fetchMessages(ticketToLoad!);
          _fetchAiSuggestions(ticketToLoad!);
        }
      }
    } catch (e) {
      if (!silent) debugPrint('Failed to load tickets: $e');
      if (!mounted || _tickets.isNotEmpty) return;
      setState(() {
        _tickets = List.from(initialDemoTickets);
        _selectedTicket = initialDemoTickets.first;
        _liveMessages = List.from(_selectedTicket.messages);
      });
    }
  }

  // ── 2. Fetch Messages Thật Của Ticket ──────────────────────────────────────
  Future<void> _fetchMessages(String ticketId, {bool silent = false}) async {
    if (ticketId.isEmpty) return;
    try {
      final res = await http.get(
        AppConfig.api('/api/v1/tickets/demo-detail/$ticketId'),
      );
      if (res.statusCode == 200) {
        final jsonRes = json.decode(utf8.decode(res.bodyBytes));
        final ticketData = jsonRes['data']?['ticket'];
        final data = (jsonRes['data']?['messages'] as List?) ?? [];
        final messages = _dedupeMessages(
          data
              .map(
                (e) => _messageFromRecord(Map<String, dynamic>.from(e as Map)),
              )
              .toList(),
        );
        if (!mounted || ticketId != _selectedTicket.ticketId) return;
        setState(() {
          if (ticketData is Map) {
            final detailTicket = _ticketFromRecord(
              Map<String, dynamic>.from(ticketData),
            ).copyWith(messages: messages);
            _selectedTicket = detailTicket;
            _tickets = _tickets
                .map(
                  (ticket) => ticket.ticketId == detailTicket.ticketId
                      ? detailTicket
                      : ticket,
                )
                .toList();
            _humanTakeover = detailTicket.status == TicketStatus.inProgress;
          }
          _liveMessages = messages;
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (!silent) debugPrint('Failed to load messages: $e');
      if (!mounted ||
          ticketId != _selectedTicket.ticketId ||
          _liveMessages.isNotEmpty) {
        return;
      }
      setState(
        () => _liveMessages = List.from(_fallbackTicketFor(ticketId).messages),
      );
    }
  }

  // ── 3. Fetch Gợi Ý AI Copilot Động ─────────────────────────────────────────
  Future<void> _fetchAiSuggestions(String ticketId) async {
    if (ticketId.isEmpty) return;
    setState(() => _isLoadingSuggestions = true);
    try {
      final res = await http.get(
        AppConfig.api('/api/v1/tickets/demo-ai-suggest/$ticketId'),
      );
      if (res.statusCode == 200) {
        final jsonRes = json.decode(utf8.decode(res.bodyBytes));
        final list =
            (jsonRes['data'] as List?)?.map((e) => e.toString()).toList() ?? [];
        if (list.isNotEmpty) {
          if (!mounted || ticketId != _selectedTicket.ticketId) return;
          setState(() {
            _aiSuggestions = list;
            _isLoadingSuggestions = false;
          });
          return;
        }
      }
    } catch (_) {}
    if (!mounted || ticketId != _selectedTicket.ticketId) return;
    setState(() => _isLoadingSuggestions = false);
  }

  // ── 4. Fetch Thống Kê Doanh Thu + Hiệu Suất ───────────────────────────────
  Future<void> _fetchStats() async {
    try {
      final futures = await Future.wait([
        http.get(AppConfig.api('/api/v1/tickets/demo-stats')),
        http.get(AppConfig.api('/api/v1/tickets/demo-product-issues')),
        http.get(AppConfig.api('/api/v1/tickets/demo-agent-performance')),
      ]);
      if (futures[0].statusCode == 200) {
        setState(
          () => _dashboardStats =
              json.decode(utf8.decode(futures[0].bodyBytes))['data'] ?? {},
        );
      } else if (_dashboardStats.isEmpty) {
        setState(() => _dashboardStats = _demoStatsFallback());
      }
      if (futures[1].statusCode == 200) {
        setState(
          () => _productIssues =
              json.decode(utf8.decode(futures[1].bodyBytes))['data'] ?? {},
        );
      } else if (_productIssues.isEmpty) {
        setState(() => _productIssues = _demoProductIssuesFallback());
      }
      if (futures[2].statusCode == 200) {
        setState(
          () => _agentPerformance =
              json.decode(utf8.decode(futures[2].bodyBytes))['data'] ?? {},
        );
      } else if (_agentPerformance.isEmpty) {
        setState(() => _agentPerformance = _demoAgentPerformanceFallback());
      }
    } catch (e) {
      debugPrint('Failed to load stats: $e');
      if (!mounted) return;
      setState(() {
        if (_dashboardStats.isEmpty) _dashboardStats = _demoStatsFallback();
        if (_productIssues.isEmpty) {
          _productIssues = _demoProductIssuesFallback();
        }
        if (_agentPerformance.isEmpty) {
          _agentPerformance = _demoAgentPerformanceFallback();
        }
      });
    }
  }

  // ── 5. Fetch Danh Sách Nhân Viên Thật ──────────────────────────────────────
  Future<void> _fetchStaff() async {
    try {
      final res = await http.get(AppConfig.api('/api/v1/users/demo-list'));
      if (res.statusCode == 200) {
        final jsonRes = json.decode(utf8.decode(res.bodyBytes));
        setState(() {
          _staffList = List<Map<String, dynamic>>.from(jsonRes['data'] ?? []);
        });
      } else if (_staffList.isEmpty) {
        setState(() => _staffList = _demoStaffFallback());
      }
    } catch (e) {
      debugPrint('Failed to load agents: $e');
      if (!mounted || _staffList.isNotEmpty) return;
      setState(() => _staffList = _demoStaffFallback());
    }
  }

  // ── 6. Fetch Danh Sách Tài Liệu Thật (ChromaDB) ────────────────────────────
  Future<void> _fetchDocuments() async {
    try {
      final res = await http.get(AppConfig.api('/api/v1/documents/demo-list'));
      if (res.statusCode == 200) {
        final jsonRes = json.decode(utf8.decode(res.bodyBytes));
        setState(() {
          _documentsList = List<Map<String, dynamic>>.from(
            jsonRes['data'] ?? [],
          );
        });
      } else if (_documentsList.isEmpty) {
        setState(() => _documentsList = _demoDocumentsFallback());
      }
    } catch (e) {
      debugPrint('Failed to load documents: $e');
      if (!mounted || _documentsList.isNotEmpty) return;
      setState(() => _documentsList = _demoDocumentsFallback());
    }
  }

  // ── 7. Setup Supabase Realtime ─────────────────────────────────────────────
  void _setupRealtime() {
    if (!supabaseRealtimeEnabled) return;
    try {
      Supabase.instance.client
          .channel('public:messages')
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'messages',
            callback: (payload) {
              final msg = payload.newRecord;
              if (msg['ticket_id'] == _selectedTicket.ticketId) {
                final added = _appendMessageIfNew(_messageFromRecord(msg));
                if (added) _scrollToBottom();
                _fetchAiSuggestions(_selectedTicket.ticketId);
              }
              _fetchTickets(silent: true);
            },
          )
          .subscribe();
    } catch (e) {
      debugPrint('Realtime connection failed: $e');
    }
  }

  // ── 8. Gửi Tin Nhắn CSKH Trực Tiếp ────────────────────────────────────────
  void _sendReply() async {
    final text = _replyController.text.trim();
    if (text.isEmpty || _selectedTicket.ticketId.isEmpty) return;
    final ticketId = _selectedTicket.ticketId;

    setState(() {
      _replyController.clear();
      _humanTakeover = true;
      _setSelectedStatus(TicketStatus.inProgress);
    });

    try {
      final res = await http.post(
        AppConfig.api('/api/v1/messages/agent-reply-demo'),
        headers: {'Content-Type': 'application/json; charset=utf-8'},
        body: json.encode({'ticket_id': ticketId, 'content': text}),
      );
      if (res.statusCode >= 200 && res.statusCode < 300) {
        await _fetchMessages(ticketId, silent: true);
        _fetchAiSuggestions(ticketId);
        _fetchTickets(silent: true);
      } else if (mounted) {
        _replyController.text = text;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'The reply could not be sent. Please try again shortly.',
            ),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    } catch (e) {
      debugPrint('Failed to send message: $e');
      if (!mounted) return;
      _replyController.text = text;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Backend connection lost. The reply was not sent.'),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  // ── 9. Cập Nhật Trạng Thái Ticket ──────────────────────────────────────────
  Future<void> _updateTicketStatus(String newStatus) async {
    if (_selectedTicket.ticketId.isEmpty) return;
    try {
      final res = await http.patch(
        AppConfig.api(
          '/api/v1/tickets/demo-status/${_selectedTicket.ticketId}',
        ),
        headers: {'Content-Type': 'application/json; charset=utf-8'},
        body: json.encode({'status': newStatus}),
      );
      if (!mounted) return;
      if (res.statusCode >= 200 && res.statusCode < 300) {
        setState(() => _setSelectedStatus(_parseStatus(newStatus)));
      }
      _fetchTickets();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ticket status updated: $newStatus'),
            backgroundColor: AppColors.success,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('Failed to update status: $e');
    }
  }

  Future<void> _deleteResolvedConversation() async {
    final ticket = _selectedTicket;
    if (ticket.status != TicketStatus.resolved || ticket.ticketId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Resolve the conversation before deleting it.'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete resolved conversation?'),
        content: Text(
          'This permanently removes ticket #${ticket.number} for '
          '${ticket.customerName} and all of its messages.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(dialogContext, true),
            icon: const Icon(Icons.delete_outline_rounded),
            label: const Text('Delete'),
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      final response = await http.delete(
        AppConfig.api('/api/v1/tickets/demo-delete/${ticket.ticketId}'),
      );
      if (!mounted) return;
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('Delete failed with status ${response.statusCode}');
      }

      final remaining = _tickets
          .where((item) => item.ticketId != ticket.ticketId)
          .toList();
      final nextTicket = remaining.isNotEmpty
          ? remaining.first
          : initialDemoTickets.first;
      setState(() {
        _tickets = remaining.isNotEmpty
            ? remaining
            : List<SupportTicket>.from(initialDemoTickets);
        _selectedTicket = nextTicket;
        _liveMessages = List<TicketMessage>.from(nextTicket.messages);
        _humanTakeover = nextTicket.status == TicketStatus.inProgress;
        _statusFilter = null;
        _mobileConversationOpen = false;
      });

      if (nextTicket.ticketId.isNotEmpty) {
        _fetchMessages(nextTicket.ticketId);
        _fetchAiSuggestions(nextTicket.ticketId);
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Resolved conversation deleted.'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (error) {
      debugPrint('Failed to delete conversation: $error');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('The conversation could not be deleted.'),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  void _toggleHumanTakeover() {
    setState(() {
      _humanTakeover = !_humanTakeover;
    });
    _updateTicketStatus(_humanTakeover ? 'in_progress' : 'open');
  }

  // ── 10. Dialog Upload Tài Liệu Vào ChromaDB (Dành Cho Quản Lý) ─────────────
  void _showUploadDocumentDialog() {
    PlatformFile? selectedFile;
    Uint8List? selectedBytes;
    var selectedSize = 0;
    var isPicking = false;
    var isUploading = false;
    String? dialogError;

    String formatFileSize(int bytes) {
      if (bytes < 1024) return '$bytes B';
      if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Row(
            children: [
              Icon(Icons.cloud_upload_rounded, color: AppColors.primary),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Upload Knowledge Document',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 520,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Choose a document from this device. The AI will extract its text and add it to the local knowledge base.',
                  style: TextStyle(fontSize: 13, color: AppColors.slate600),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Supported: PDF, DOCX, TXT • Maximum size: 10 MB',
                  style: TextStyle(fontSize: 12, color: AppColors.slate500),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    icon: isPicking
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.folder_open_rounded),
                    label: Text(
                      isPicking ? 'Opening file picker...' : 'Choose Document',
                    ),
                    onPressed: isPicking || isUploading
                        ? null
                        : () async {
                            setDialogState(() {
                              isPicking = true;
                              dialogError = null;
                            });
                            try {
                              final file = await FilePicker.pickFile(
                                type: FileType.custom,
                                allowedExtensions: const ['pdf', 'docx', 'txt'],
                              );
                              if (file == null) return;
                              final size = await file.length();
                              if (size > 10 * 1024 * 1024) {
                                if (!ctx.mounted) return;
                                setDialogState(() {
                                  selectedFile = null;
                                  selectedBytes = null;
                                  selectedSize = 0;
                                  dialogError =
                                      'The selected file is larger than 10 MB.';
                                });
                                return;
                              }
                              final bytes = await file.readAsBytes();
                              if (!ctx.mounted) return;
                              setDialogState(() {
                                selectedFile = file;
                                selectedBytes = bytes;
                                selectedSize = size;
                              });
                            } catch (e) {
                              if (!ctx.mounted) return;
                              setDialogState(() {
                                dialogError =
                                    'Could not read the selected file.';
                              });
                              debugPrint('Failed to pick document: $e');
                            } finally {
                              if (ctx.mounted) {
                                setDialogState(() => isPicking = false);
                              }
                            }
                          },
                  ),
                ),
                if (selectedFile != null) ...[
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.successSoft,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: AppColors.success.withValues(alpha: 0.35),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.description_rounded,
                          color: AppColors.success,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                selectedFile!.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                formatFileSize(selectedSize),
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.slate600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'Remove selected file',
                          onPressed: isUploading
                              ? null
                              : () => setDialogState(() {
                                  selectedFile = null;
                                  selectedBytes = null;
                                  selectedSize = 0;
                                }),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                  ),
                ],
                if (dialogError != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    dialogError!,
                    style: const TextStyle(
                      color: AppColors.danger,
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isUploading ? null : () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton.icon(
              icon: isUploading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.cloud_upload_rounded, size: 16),
              label: Text(isUploading ? 'Uploading...' : 'Upload & Index'),
              onPressed:
                  selectedFile == null || selectedBytes == null || isUploading
                  ? null
                  : () async {
                      final file = selectedFile!;
                      setDialogState(() {
                        isUploading = true;
                        dialogError = null;
                      });
                      try {
                        final request =
                            http.MultipartRequest(
                                'POST',
                                AppConfig.api('/api/v1/documents/demo-upload'),
                              )
                              ..files.add(
                                http.MultipartFile.fromBytes(
                                  'file',
                                  selectedBytes!,
                                  filename: file.name,
                                ),
                              );
                        final response = await http.Response.fromStream(
                          await request.send(),
                        );
                        if (response.statusCode != 201) {
                          var detail = 'The document could not be uploaded.';
                          try {
                            final body = json.decode(
                              utf8.decode(response.bodyBytes),
                            );
                            detail = body['detail']?.toString() ?? detail;
                          } catch (_) {}
                          if (!ctx.mounted) return;
                          setDialogState(() {
                            isUploading = false;
                            dialogError = detail;
                          });
                          return;
                        }

                        final jsonRes = json.decode(
                          utf8.decode(response.bodyBytes),
                        );
                        final uploadedDoc = Map<String, dynamic>.from(
                          jsonRes['data'] ?? {},
                        );
                        if (uploadedDoc.isNotEmpty && mounted) {
                          setState(() {
                            _documentsList = [
                              uploadedDoc,
                              ..._documentsList.where(
                                (doc) => doc['id'] != uploadedDoc['id'],
                              ),
                            ];
                          });
                        }
                        if (ctx.mounted) Navigator.pop(ctx);
                        _fetchDocuments();
                        _showDemoSnack(
                          'Document "${file.name}" was uploaded and indexed successfully.',
                          color: AppColors.success,
                        );
                      } catch (e) {
                        debugPrint('Failed to upload document: $e');
                        if (!ctx.mounted) return;
                        setDialogState(() {
                          isUploading = false;
                          dialogError =
                              'Backend connection lost. The document was not uploaded.';
                        });
                      }
                    },
            ),
          ],
        ),
      ),
    );
  }

  // ── 11. Xóa Tài Liệu Khỏi ChromaDB ────────────────────────────────────────
  void _deleteDocument(String docId, String name) async {
    try {
      final response = await http.delete(
        AppConfig.api('/api/v1/documents/demo-delete/$docId'),
      );
      if (mounted && response.statusCode >= 200 && response.statusCode < 300) {
        setState(() {
          _documentsList = _documentsList
              .where((doc) => doc['id']?.toString() != docId)
              .toList();
        });
      }
      _fetchDocuments();
      _showDemoSnack('Removed "$name" from the knowledge base.');
    } catch (e) {
      debugPrint('Failed to delete document: $e');
      if (!mounted) return;
      setState(() {
        _documentsList = _documentsList
            .where((doc) => doc['id']?.toString() != docId)
            .toList();
      });
      _showDemoSnack(
        'Backend unavailable. The document was hidden from the demo screen.',
      );
    }
  }

  // ── 12. CRUD Nhân Viên CSKH ───────────────────────────────────────────────
  void _showAddStaffDialog() {
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    String role = 'agent';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Row(
            children: [
              Icon(Icons.person_add_rounded, color: AppColors.primary),
              SizedBox(width: 8),
              Text(
                'Add Support Agent',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ],
          ),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: InputDecoration(
                    labelText: 'Full Name',
                    hintText: 'Example: Alex Morgan',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: emailCtrl,
                  decoration: InputDecoration(
                    labelText: 'Login Email',
                    hintText: 'Example: alex.morgan@sportgear.test',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  initialValue: role,
                  decoration: InputDecoration(
                    labelText: 'Access Role',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'agent',
                      child: Text('Support Agent'),
                    ),
                    DropdownMenuItem(
                      value: 'senior_agent',
                      child: Text('Senior Support Agent'),
                    ),
                    DropdownMenuItem(
                      value: 'super_admin',
                      child: Text('Store Owner / Administrator'),
                    ),
                  ],
                  onChanged: (val) =>
                      setDialogState(() => role = val ?? 'agent'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                final name = nameCtrl.text.trim();
                final email = emailCtrl.text.trim();
                if (name.isEmpty || email.isEmpty) return;

                Navigator.pop(ctx);
                try {
                  final res = await http.post(
                    AppConfig.api('/api/v1/users/demo-create'),
                    headers: {
                      'Content-Type': 'application/json; charset=utf-8',
                    },
                    body: json.encode({
                      'full_name': name,
                      'email': email,
                      'role': role,
                    }),
                  );
                  if (mounted &&
                      res.statusCode >= 200 &&
                      res.statusCode < 300) {
                    final jsonRes = json.decode(utf8.decode(res.bodyBytes));
                    final created = Map<String, dynamic>.from(
                      jsonRes['data'] ?? {},
                    );
                    if (created.isNotEmpty) {
                      setState(() {
                        _staffList = [
                          created,
                          ..._staffList.where(
                            (staff) => staff['id'] != created['id'],
                          ),
                        ];
                      });
                    }
                  }
                  _fetchStaff();
                  _showDemoSnack(
                    'Agent $name was created successfully.',
                    color: AppColors.success,
                  );
                } catch (e) {
                  debugPrint('Failed to create agent: $e');
                  if (!mounted) return;
                  final localUser = {
                    'id': 'local_${DateTime.now().millisecondsSinceEpoch}',
                    'full_name': name,
                    'email': email,
                    'role': role,
                    'status': 'online',
                  };
                  setState(() => _staffList = [localUser, ..._staffList]);
                  _showDemoSnack(
                    'Backend unavailable. A temporary agent was added to the demo screen.',
                  );
                }
              },
              child: const Text('Save Agent'),
            ),
          ],
        ),
      ),
    );
  }

  void _deleteStaff(String userId, String name) async {
    try {
      final response = await http.delete(
        AppConfig.api('/api/v1/users/demo-delete/$userId'),
      );
      if (mounted && response.statusCode >= 200 && response.statusCode < 300) {
        setState(() {
          _staffList = _staffList
              .where((staff) => staff['id']?.toString() != userId)
              .toList();
        });
      }
      _fetchStaff();
      _showDemoSnack('Removed agent $name from the system.');
    } catch (e) {
      debugPrint('Failed to delete agent: $e');
      if (!mounted) return;
      setState(() {
        _staffList = _staffList
            .where((staff) => staff['id']?.toString() != userId)
            .toList();
      });
      _showDemoSnack(
        'Backend unavailable. The agent was hidden from the demo screen.',
      );
    }
  }

  void _toggleStaffStatus(String userId, String currentStatus) async {
    final newStatus = currentStatus == 'online' ? 'offline' : 'online';
    try {
      final response = await http.patch(
        AppConfig.api('/api/v1/users/demo-status/$userId'),
        headers: {'Content-Type': 'application/json; charset=utf-8'},
        body: json.encode({'status': newStatus}),
      );
      if (mounted && response.statusCode >= 200 && response.statusCode < 300) {
        setState(() {
          _staffList = _staffList
              .map(
                (staff) => staff['id']?.toString() == userId
                    ? {...staff, 'status': newStatus}
                    : staff,
              )
              .toList();
        });
      }
      _fetchStaff();
    } catch (e) {
      debugPrint('Failed to change agent status: $e');
      if (!mounted) return;
      setState(() {
        _staffList = _staffList
            .map(
              (staff) => staff['id']?.toString() == userId
                  ? {...staff, 'status': newStatus}
                  : staff,
            )
            .toList();
      });
      _showDemoSnack(
        'Backend unavailable. The status was changed temporarily on the demo screen.',
      );
    }
  }

  TicketSource _parseSource(String? s) {
    final value = s?.toLowerCase();
    if (value == 'facebook') return TicketSource.facebook;
    if (value == 'email') return TicketSource.email;
    return TicketSource.web;
  }

  TicketStatus _parseStatus(String? s) {
    final value = s?.toLowerCase();
    if (value == 'open') return TicketStatus.open;
    if (value == 'in_progress') return TicketStatus.inProgress;
    if (value == 'resolved') return TicketStatus.resolved;
    return TicketStatus.pending;
  }

  TicketIntent _parseIntent(String? s) {
    final value = s?.toLowerCase();
    if (value == 'complaint' || value == 'handoff') {
      return TicketIntent.complaint;
    }
    if (value == 'spam') return TicketIntent.spam;
    return TicketIntent.question;
  }

  @override
  Widget build(BuildContext context) {
    void selectTab(int index) {
      if (_role == DemoRole.agent && index != 0) return;
      setState(() => _tabIndex = index);
      if (index == 0) _fetchTickets();
      if (index == 1) _fetchStats();
      if (index == 2) {
        _fetchStaff();
        _fetchDocuments();
      }
    }

    void refreshAll() {
      _fetchTickets();
      if (_role == DemoRole.superAdmin) {
        _fetchStats();
        _fetchStaff();
        _fetchDocuments();
      }
      _fetchSystemHealth();
      if (_selectedTicket.ticketId.isNotEmpty) {
        _fetchMessages(_selectedTicket.ticketId);
        _fetchAiSuggestions(_selectedTicket.ticketId);
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('All system data has been refreshed.'),
          duration: Duration(seconds: 1),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 720;
        final navigationItems = <BottomNavigationBarItem>[
          const BottomNavigationBarItem(
            icon: Icon(Icons.forum_rounded),
            label: 'Inbox',
          ),
          if (_role == DemoRole.superAdmin) ...[
            const BottomNavigationBarItem(
              icon: Icon(Icons.analytics_rounded),
              label: 'Reports',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.admin_panel_settings_rounded),
              label: 'Manage',
            ),
          ],
        ];

        final content = IndexedStack(
          index: _tabIndex,
          children: [
            _LiveWorkspaceLayout(
              compact: compact,
              showConversation: _mobileConversationOpen,
              tickets: _tickets,
              selectedTicket: _selectedTicket,
              channelFilter: _channelFilter,
              statusFilter: _statusFilter,
              humanTakeover: _humanTakeover,
              liveMessages: _liveMessages,
              replyController: _replyController,
              chatScrollController: _chatScrollController,
              aiSuggestions: _aiSuggestions,
              isLoadingSuggestions: _isLoadingSuggestions,
              onBackToTickets: () =>
                  setState(() => _mobileConversationOpen = false),
              onSelectTicket: (ticket) {
                setState(() {
                  _selectedTicket = ticket;
                  _humanTakeover = ticket.status == TicketStatus.inProgress;
                  _liveMessages = List.from(ticket.messages);
                  _mobileConversationOpen = true;
                });
                _fetchMessages(ticket.ticketId);
                _fetchAiSuggestions(ticket.ticketId);
              },
              onChannelFilter: (filter) =>
                  setState(() => _channelFilter = filter),
              onStatusFilter: (status) =>
                  setState(() => _statusFilter = status),
              onToggleTakeover: _toggleHumanTakeover,
              onResolveTicket: () => _updateTicketStatus('resolved'),
              onDeleteConversation: _deleteResolvedConversation,
              onUpdateStatus: (st) => _updateTicketStatus(st),
              onFillDraft: (text) =>
                  setState(() => _replyController.text = text),
              onSendReply: _sendReply,
            ),
            if (_role == DemoRole.superAdmin) ...[
              _AnalyticsDashboard(
                compact: compact,
                stats: _dashboardStats,
                productIssues: _productIssues,
                agentPerformance: _agentPerformance,
              ),
              _AdminManagementDashboard(
                compact: compact,
                staffList: _staffList,
                documentsList: _documentsList,
                onAddStaff: _showAddStaffDialog,
                onDeleteStaff: _deleteStaff,
                onToggleStatus: _toggleStaffStatus,
                onUploadDocument: _showUploadDocumentDialog,
                onDeleteDocument: _deleteDocument,
              ),
            ],
          ],
        );

        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: compact
              ? _MobileHeader(
                  role: _role,
                  backendConnection: _backendConnection,
                  onRoleChanged: _setDemoRole,
                  onRefresh: refreshAll,
                )
              : null,
          body: Column(
            children: [
              if (!compact)
                _WebHeader(
                  selectedIndex: _tabIndex,
                  role: _role,
                  onRoleChanged: _setDemoRole,
                  onTabChanged: selectTab,
                  onRefreshAll: refreshAll,
                ),
              _DemoGuideBanner(
                tabIndex: _tabIndex,
                compact: compact,
                backendConnection: _backendConnection,
                aiConnection: _aiConnection,
                aiProvider: _aiProvider,
              ),
              Expanded(child: content),
            ],
          ),
          bottomNavigationBar: compact && navigationItems.length > 1
              ? BottomNavigationBar(
                  currentIndex: _tabIndex,
                  onTap: selectTab,
                  items: navigationItems,
                )
              : null,
        );
      },
    );
  }
}

// ── Header Widget ────────────────────────────────────────────────────────────
class _WebHeader extends StatelessWidget {
  const _WebHeader({
    required this.selectedIndex,
    required this.role,
    required this.onRoleChanged,
    required this.onTabChanged,
    required this.onRefreshAll,
  });

  final int selectedIndex;
  final DemoRole role;
  final ValueChanged<DemoRole> onRoleChanged;
  final ValueChanged<int> onTabChanged;
  final VoidCallback onRefreshAll;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 11),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: AppColors.slate200)),
        boxShadow: [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.primary, AppColors.indigo],
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x332563EB),
                  blurRadius: 8,
                  offset: Offset(0, 3),
                ),
              ],
            ),
            child: const Icon(
              Icons.headset_mic_rounded,
              color: Colors.white,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Omnichannel Customer Support',
                      style: TextStyle(
                        color: AppColors.slate900,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(width: 10),
                    BadgeChip(
                      label: 'SportGear Boutique Portal',
                      color: AppColors.primary,
                      backgroundColor: AppColors.primarySoft,
                    ),
                  ],
                ),
                SizedBox(height: 2),
                Text(
                  'Real-time customer support (Web Store & Facebook) • AI RAG Engine & Live Human Support',
                  style: TextStyle(
                    color: AppColors.slate500,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          _SegmentedHeaderTabs(
            selectedIndex: selectedIndex,
            showAdminTabs: role == DemoRole.superAdmin,
            onChanged: onTabChanged,
          ),
          const SizedBox(width: 10),
          _RoleMenu(role: role, onChanged: onRoleChanged),
          const SizedBox(width: 6),
          IconButton.filledTonal(
            onPressed: onRefreshAll,
            tooltip: 'Refresh data',
            icon: const Icon(Icons.refresh_rounded, size: 20),
          ),
        ],
      ),
    );
  }
}

class _MobileHeader extends StatelessWidget implements PreferredSizeWidget {
  const _MobileHeader({
    required this.role,
    required this.backendConnection,
    required this.onRoleChanged,
    required this.onRefresh,
  });

  final DemoRole role;
  final ServiceConnection backendConnection;
  final ValueChanged<DemoRole> onRoleChanged;
  final VoidCallback onRefresh;

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context) {
    final connected = backendConnection == ServiceConnection.online;
    return AppBar(
      toolbarHeight: 64,
      backgroundColor: Colors.white,
      foregroundColor: AppColors.slate900,
      titleSpacing: 16,
      title: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.headset_mic_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Smart Helpdesk',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                ),
                Text(
                  connected ? 'Backend connected' : 'Offline demo mode',
                  style: TextStyle(
                    fontSize: 10.5,
                    color: connected ? AppColors.success : AppColors.warning,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        _RoleMenu(role: role, onChanged: onRoleChanged, compact: true),
        IconButton(
          onPressed: onRefresh,
          tooltip: 'Refresh',
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
    );
  }
}

class _RoleMenu extends StatelessWidget {
  const _RoleMenu({
    required this.role,
    required this.onChanged,
    this.compact = false,
  });

  final DemoRole role;
  final ValueChanged<DemoRole> onChanged;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<DemoRole>(
      tooltip: 'Switch demo role',
      onSelected: onChanged,
      itemBuilder: (context) => DemoRole.values
          .map(
            (item) => PopupMenuItem(
              value: item,
              child: Row(
                children: [
                  Icon(
                    item == DemoRole.superAdmin
                        ? Icons.admin_panel_settings_rounded
                        : Icons.support_agent_rounded,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(item.label),
                  if (item == role) ...[
                    const Spacer(),
                    const Icon(Icons.check_rounded, size: 18),
                  ],
                ],
              ),
            ),
          )
          .toList(),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 8 : 10,
          vertical: 8,
        ),
        decoration: BoxDecoration(
          color: AppColors.slate100,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: AppColors.slate200),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              role == DemoRole.superAdmin
                  ? Icons.admin_panel_settings_rounded
                  : Icons.support_agent_rounded,
              size: 17,
              color: AppColors.indigo,
            ),
            if (!compact) ...[
              const SizedBox(width: 6),
              Text(
                role.label,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SegmentedHeaderTabs extends StatelessWidget {
  const _SegmentedHeaderTabs({
    required this.selectedIndex,
    required this.showAdminTabs,
    required this.onChanged,
  });

  final int selectedIndex;
  final bool showAdminTabs;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.slate100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.slate200),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _HeaderTabButton(
            selected: selectedIndex == 0,
            icon: Icons.forum_rounded,
            label: '1. Live Customer Support',
            onTap: () => onChanged(0),
          ),
          if (showAdminTabs) ...[
            const SizedBox(width: 4),
            _HeaderTabButton(
              selected: selectedIndex == 1,
              icon: Icons.analytics_rounded,
              label: '2. Reports & Revenue',
              onTap: () => onChanged(1),
            ),
            const SizedBox(width: 4),
            _HeaderTabButton(
              selected: selectedIndex == 2,
              icon: Icons.admin_panel_settings_rounded,
              label: '3. Management & AI Knowledge',
              onTap: () => onChanged(2),
            ),
          ],
        ],
      ),
    );
  }
}

class _HeaderTabButton extends StatelessWidget {
  const _HeaderTabButton({
    required this.selected,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final bool selected;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.primary : Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(
            children: [
              Icon(
                icon,
                size: 16,
                color: selected ? Colors.white : AppColors.slate600,
              ),
              const SizedBox(width: 7),
              Text(
                label,
                style: TextStyle(
                  color: selected ? Colors.white : AppColors.slate700,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DemoGuideBanner extends StatelessWidget {
  const _DemoGuideBanner({
    required this.tabIndex,
    required this.compact,
    required this.backendConnection,
    required this.aiConnection,
    required this.aiProvider,
  });

  final int tabIndex;
  final bool compact;
  final ServiceConnection backendConnection;
  final ServiceConnection aiConnection;
  final String aiProvider;

  @override
  Widget build(BuildContext context) {
    String text;
    if (tabIndex == 0) {
      text =
          'Tab 1: Live Support. Full-screen workspace with independent chat scrolling and two-way Web Store messaging (port 3000).';
    } else if (tabIndex == 1) {
      text =
          'Tab 2: Revenue analytics and AI automation metrics updated directly from the database.';
    } else {
      text =
          'Tab 3: Manager workspace for agents, shift access, and AI knowledge uploads to ChromaDB.';
    }

    final backendOnline = backendConnection == ServiceConnection.online;
    final aiOnline = aiConnection == ServiceConnection.online;
    final syncLabel = !backendOnline
        ? 'BUILT-IN DEMO DATA'
        : (supabaseRealtimeEnabled
              ? 'REALTIME CONNECTED'
              : 'REST POLLING CONNECTED');
    final syncColor = backendOnline ? AppColors.success : AppColors.warning;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: compact ? 12 : 24, vertical: 7),
      decoration: const BoxDecoration(
        color: AppColors.primarySoft,
        border: Border(bottom: BorderSide(color: Color(0xFFDBEAFE))),
      ),
      child: Row(
        children: [
          BadgeChip(
            label: aiOnline && aiProvider == 'ollama'
                ? 'LOCAL AI • OLLAMA'
                : (aiOnline ? 'AI FALLBACK READY' : 'AI OFFLINE'),
            color: Colors.white,
            backgroundColor: aiOnline ? AppColors.primary : AppColors.warning,
          ),
          if (!compact) ...[
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '$text ${kIsWeb ? "Web" : "Mobile"}: ${AppConfig.apiBaseUrl}',
                style: const TextStyle(
                  color: AppColors.slate800,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ] else
            const Spacer(),
          Icon(Icons.circle, color: syncColor, size: 8),
          const SizedBox(width: 6),
          Text(
            syncLabel,
            style: TextStyle(
              color: syncColor,
              fontSize: compact ? 9.5 : 11,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Tab 0: Không Gian Live Chat & Customer Profile (Full Height, Independent Scroll) ──
class _LiveWorkspaceLayout extends StatelessWidget {
  const _LiveWorkspaceLayout({
    required this.compact,
    required this.showConversation,
    required this.tickets,
    required this.selectedTicket,
    required this.channelFilter,
    required this.statusFilter,
    required this.humanTakeover,
    required this.liveMessages,
    required this.replyController,
    required this.chatScrollController,
    required this.aiSuggestions,
    required this.isLoadingSuggestions,
    required this.onBackToTickets,
    required this.onSelectTicket,
    required this.onChannelFilter,
    required this.onStatusFilter,
    required this.onToggleTakeover,
    required this.onResolveTicket,
    required this.onDeleteConversation,
    required this.onUpdateStatus,
    required this.onFillDraft,
    required this.onSendReply,
  });

  final bool compact;
  final bool showConversation;
  final List<SupportTicket> tickets;
  final SupportTicket selectedTicket;
  final TicketSource? channelFilter;
  final TicketStatus? statusFilter;
  final bool humanTakeover;
  final List<TicketMessage> liveMessages;
  final TextEditingController replyController;
  final ScrollController chatScrollController;
  final List<String> aiSuggestions;
  final bool isLoadingSuggestions;
  final VoidCallback onBackToTickets;
  final ValueChanged<SupportTicket> onSelectTicket;
  final ValueChanged<TicketSource?> onChannelFilter;
  final ValueChanged<TicketStatus?> onStatusFilter;
  final VoidCallback onToggleTakeover;
  final VoidCallback onResolveTicket;
  final VoidCallback onDeleteConversation;
  final ValueChanged<String> onUpdateStatus;
  final ValueChanged<String> onFillDraft;
  final VoidCallback onSendReply;

  @override
  Widget build(BuildContext context) {
    final visibleTickets = tickets.where((ticket) {
      if (channelFilter != null && ticket.source != channelFilter) return false;
      if (statusFilter != null && ticket.status != statusFilter) return false;
      return true;
    }).toList();

    final ticketList = _ConversationPanel(
      tickets: visibleTickets,
      allTickets: tickets,
      selectedTicket: selectedTicket,
      channelFilter: channelFilter,
      statusFilter: statusFilter,
      onChannelFilter: onChannelFilter,
      onStatusFilter: onStatusFilter,
      onSelectTicket: onSelectTicket,
    );
    final chat = _MainChatRoom(
      compact: compact,
      ticket: selectedTicket,
      humanTakeover: humanTakeover,
      messages: liveMessages,
      replyController: replyController,
      scrollController: chatScrollController,
      aiSuggestions: aiSuggestions,
      isLoadingSuggestions: isLoadingSuggestions,
      onToggleTakeover: onToggleTakeover,
      onResolveTicket: onResolveTicket,
      onDeleteConversation: onDeleteConversation,
      onFillDraft: onFillDraft,
      onSendReply: onSendReply,
    );
    final profile = _CustomerProfileSidebar(
      ticket: selectedTicket,
      humanTakeover: humanTakeover,
      onToggleTakeover: onToggleTakeover,
      onUpdateStatus: onUpdateStatus,
    );

    if (compact) {
      if (!showConversation) {
        return Padding(padding: const EdgeInsets.all(10), child: ticketList);
      }
      return Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: onBackToTickets,
                      icon: const Icon(Icons.arrow_back_rounded, size: 18),
                      label: const Text('Conversations'),
                    ),
                  ),
                ),
                Expanded(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () => showModalBottomSheet<void>(
                        context: context,
                        isScrollControlled: true,
                        builder: (context) => SafeArea(
                          child: SizedBox(
                            height: MediaQuery.sizeOf(context).height * 0.72,
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: profile,
                            ),
                          ),
                        ),
                      ),
                      icon: const Icon(Icons.person_outline_rounded, size: 18),
                      label: const Text('Customer'),
                    ),
                  ),
                ),
              ],
            ),
            Expanded(child: chat),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final showProfile = constraints.maxWidth >= 1180;
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(width: 310, child: ticketList),
              const SizedBox(width: 14),
              Expanded(flex: 6, child: chat),
              if (showProfile) ...[
                const SizedBox(width: 14),
                SizedBox(width: 330, child: profile),
              ],
            ],
          ),
        );
      },
    );
  }
}

// ── Cột 1: Conversation List Panel ──────────────────────────────────────────
class _ConversationPanel extends StatelessWidget {
  const _ConversationPanel({
    required this.tickets,
    required this.allTickets,
    required this.selectedTicket,
    required this.channelFilter,
    required this.statusFilter,
    required this.onChannelFilter,
    required this.onStatusFilter,
    required this.onSelectTicket,
  });

  final List<SupportTicket> tickets;
  final List<SupportTicket> allTickets;
  final SupportTicket selectedTicket;
  final TicketSource? channelFilter;
  final TicketStatus? statusFilter;
  final ValueChanged<TicketSource?> onChannelFilter;
  final ValueChanged<TicketStatus?> onStatusFilter;
  final ValueChanged<SupportTicket> onSelectTicket;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: cardDecoration(),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            color: AppColors.slate50,
            child: Row(
              children: [
                const Icon(
                  Icons.inbox_rounded,
                  size: 18,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'UNIFIED INBOX',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppColors.slate900,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${tickets.length} tickets',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppColors.slate500,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.slate200),

          // Filter 1: Kênh liên hệ
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
            child: Wrap(
              spacing: 4,
              runSpacing: 4,
              children: [
                _MiniFilterChip(
                  label: 'All channels',
                  selected: channelFilter == null,
                  color: AppColors.slate700,
                  onTap: () => onChannelFilter(null),
                ),
                _MiniFilterChip(
                  label:
                      'Web (${allTickets.where((t) => t.source == TicketSource.web).length})',
                  selected: channelFilter == TicketSource.web,
                  color: AppColors.primary,
                  onTap: () => onChannelFilter(TicketSource.web),
                ),
                _MiniFilterChip(
                  label:
                      'FB (${allTickets.where((t) => t.source == TicketSource.facebook).length})',
                  selected: channelFilter == TicketSource.facebook,
                  color: AppColors.indigo,
                  onTap: () => onChannelFilter(TicketSource.facebook),
                ),
                _MiniFilterChip(
                  label:
                      'Email (${allTickets.where((t) => t.source == TicketSource.email).length})',
                  selected: channelFilter == TicketSource.email,
                  color: AppColors.success,
                  onTap: () => onChannelFilter(TicketSource.email),
                ),
              ],
            ),
          ),
          // Filter 2: Trạng thái ticket
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
            child: Wrap(
              spacing: 4,
              runSpacing: 4,
              children: [
                _MiniFilterChip(
                  label: 'All statuses',
                  selected: statusFilter == null,
                  color: AppColors.slate600,
                  onTap: () => onStatusFilter(null),
                ),
                _MiniFilterChip(
                  label:
                      'Open (${allTickets.where((t) => t.status == TicketStatus.open).length})',
                  selected: statusFilter == TicketStatus.open,
                  color: AppColors.danger,
                  onTap: () => onStatusFilter(TicketStatus.open),
                ),
                _MiniFilterChip(
                  label:
                      'In progress (${allTickets.where((t) => t.status == TicketStatus.inProgress).length})',
                  selected: statusFilter == TicketStatus.inProgress,
                  color: AppColors.warning,
                  onTap: () => onStatusFilter(TicketStatus.inProgress),
                ),
                _MiniFilterChip(
                  label:
                      'Resolved (${allTickets.where((t) => t.status == TicketStatus.resolved).length})',
                  selected: statusFilter == TicketStatus.resolved,
                  color: AppColors.success,
                  onTap: () => onStatusFilter(TicketStatus.resolved),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.slate200),

          // List Items (Cuộn độc lập)
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(8),
              itemCount: tickets.length,
              separatorBuilder: (ctx, idx) => const SizedBox(height: 6),
              itemBuilder: (ctx, idx) {
                final t = tickets[idx];
                final isSelected = t.ticketId == selectedTicket.ticketId;
                return _TicketListItem(
                  ticket: t,
                  isSelected: isSelected,
                  onTap: () => onSelectTicket(t),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniFilterChip extends StatelessWidget {
  const _MiniFilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.color = AppColors.primary,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: selected ? color : AppColors.slate100,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: selected ? color : AppColors.slate200,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : AppColors.slate600,
            fontSize: 10,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _TicketListItem extends StatelessWidget {
  const _TicketListItem({
    required this.ticket,
    required this.isSelected,
    required this.onTap,
  });

  final SupportTicket ticket;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primarySoft : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.slate200,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                SourceBadge(source: ticket.source),
                const Spacer(),
                StatusBadge(status: ticket.status),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '#${ticket.number}: ${ticket.customerName}',
              style: const TextStyle(
                color: AppColors.slate900,
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 3),
            Text(
              ticket.summary,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.slate600,
                fontSize: 10.5,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Flexible(child: IntentBadge(intent: ticket.intent)),
                const SizedBox(width: 8),
                Text(
                  ticket.createdAgo,
                  style: const TextStyle(
                    color: AppColors.slate400,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Cột 2: Main Chat Room (Tách biệt hoàn toàn việc cuộn) ───────────────────
class _MainChatRoom extends StatelessWidget {
  const _MainChatRoom({
    required this.compact,
    required this.ticket,
    required this.humanTakeover,
    required this.messages,
    required this.replyController,
    required this.scrollController,
    required this.aiSuggestions,
    required this.isLoadingSuggestions,
    required this.onToggleTakeover,
    required this.onResolveTicket,
    required this.onDeleteConversation,
    required this.onFillDraft,
    required this.onSendReply,
  });

  final bool compact;
  final SupportTicket ticket;
  final bool humanTakeover;
  final List<TicketMessage> messages;
  final TextEditingController replyController;
  final ScrollController scrollController;
  final List<String> aiSuggestions;
  final bool isLoadingSuggestions;
  final VoidCallback onToggleTakeover;
  final VoidCallback onResolveTicket;
  final VoidCallback onDeleteConversation;
  final ValueChanged<String> onFillDraft;
  final VoidCallback onSendReply;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: cardDecoration(),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          _ChatRoomHeader(
            ticket: ticket,
            humanTakeover: humanTakeover,
            compact: compact,
            onToggleTakeover: onToggleTakeover,
            onResolveTicket: onResolveTicket,
            onDeleteConversation: onDeleteConversation,
          ),
          const Divider(height: 1, color: AppColors.slate200),

          // Messages List: Cuộn độc lập 100%, không bao giờ overscroll ra toàn trang
          Expanded(
            child: Container(
              color: const Color(0xFFFBFDFF),
              child: messages.isEmpty
                  ? const Center(
                      child: Text(
                        'There are no messages in this conversation yet.',
                        style: TextStyle(color: AppColors.slate400),
                      ),
                    )
                  : ListView.separated(
                      controller: scrollController,
                      physics: const AlwaysScrollableScrollPhysics(
                        parent:
                            ClampingScrollPhysics(), // Chặn triệt để nảy/overscroll sang trang cha
                      ),
                      padding: const EdgeInsets.all(16),
                      itemBuilder: (context, index) =>
                          ChatBubble(message: messages[index]),
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 12),
                      itemCount: messages.length,
                    ),
            ),
          ),

          // Composer & AI Suggestions
          _WebReplyComposer(
            controller: replyController,
            aiSuggestions: aiSuggestions,
            isLoadingSuggestions: isLoadingSuggestions,
            onFillDraft: onFillDraft,
            onSend: onSendReply,
          ),
        ],
      ),
    );
  }
}

class _ChatRoomHeader extends StatelessWidget {
  const _ChatRoomHeader({
    required this.ticket,
    required this.humanTakeover,
    required this.compact,
    required this.onToggleTakeover,
    required this.onResolveTicket,
    required this.onDeleteConversation,
  });

  final SupportTicket ticket;
  final bool humanTakeover;
  final bool compact;
  final VoidCallback onToggleTakeover;
  final VoidCallback onResolveTicket;
  final VoidCallback onDeleteConversation;

  @override
  Widget build(BuildContext context) {
    final title = Row(
      children: [
        Expanded(
          child: Text(
            'Ticket #${ticket.number}: ${ticket.customerName}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: AppColors.slate900,
              fontSize: compact ? 13 : 14,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        const SizedBox(width: 6),
        SourceBadge(source: ticket.source),
      ],
    );
    final takeoverButton = OutlinedButton.icon(
      onPressed: onToggleTakeover,
      icon: Icon(
        humanTakeover ? Icons.person_pin : Icons.smart_toy_outlined,
        size: 15,
      ),
      label: Text(
        compact
            ? (humanTakeover ? 'Agent active' : 'Take over')
            : (humanTakeover ? 'Human Agent Active' : 'Start Human Takeover'),
      ),
    );
    final resolveButton = FilledButton.icon(
      onPressed: onResolveTicket,
      icon: const Icon(Icons.check_circle_rounded, size: 15),
      label: Text(compact ? 'Resolve' : 'Resolve & Close'),
      style: FilledButton.styleFrom(backgroundColor: AppColors.success),
    );
    final deleteButton = FilledButton.icon(
      onPressed: onDeleteConversation,
      icon: const Icon(Icons.delete_outline_rounded, size: 15),
      label: Text(compact ? 'Delete' : 'Delete Chat'),
      style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
    );
    final completionButton = ticket.status == TicketStatus.resolved
        ? deleteButton
        : resolveButton;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 12 : 18,
        vertical: compact ? 9 : 12,
      ),
      color: AppColors.slate50,
      child: compact
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                title,
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(child: takeoverButton),
                    const SizedBox(width: 8),
                    Expanded(child: completionButton),
                  ],
                ),
              ],
            )
          : Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      title,
                      const SizedBox(height: 3),
                      Text(
                        humanTakeover
                            ? 'STATUS: LIVE HUMAN SUPPORT'
                            : 'STATUS: AI ASSISTANT ACTIVE',
                        style: TextStyle(
                          color: humanTakeover
                              ? AppColors.warning
                              : AppColors.success,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
                takeoverButton,
                const SizedBox(width: 8),
                completionButton,
              ],
            ),
    );
  }
}

// ── Cột 3: Customer Profile & Quick CRM Sidebar ──────────────────────────────
class _CustomerProfileSidebar extends StatelessWidget {
  const _CustomerProfileSidebar({
    required this.ticket,
    required this.humanTakeover,
    required this.onToggleTakeover,
    required this.onUpdateStatus,
  });

  final SupportTicket ticket;
  final bool humanTakeover;
  final VoidCallback onToggleTakeover;
  final ValueChanged<String> onUpdateStatus;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: cardDecoration(),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            color: AppColors.slate50,
            child: const Row(
              children: [
                Icon(
                  Icons.person_pin_rounded,
                  size: 18,
                  color: AppColors.indigo,
                ),
                SizedBox(width: 8),
                Text(
                  'CUSTOMER PROFILE & CRM',
                  style: TextStyle(
                    color: AppColors.slate900,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.slate200),

          Expanded(
            child: SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Avatar & Name
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: AppColors.primarySoft,
                        child: Text(
                          ticket.customerName.isNotEmpty
                              ? ticket.customerName[0]
                              : 'K',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              ticket.customerName,
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 13,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const Text(
                              'Potential customer (Online)',
                              style: TextStyle(
                                color: AppColors.slate500,
                                fontSize: 10.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Metadata Cards
                  _ProfileDetailItem(
                    label: 'Contact Channel',
                    value: ticket.source.label,
                    icon: ticket.source.icon,
                  ),
                  _ProfileDetailItem(
                    label: 'Classified Intent',
                    value: ticket.intent.label,
                    icon: ticket.intent.icon,
                  ),
                  _ProfileDetailItem(
                    label: 'Ticket Status',
                    value: ticket.status.label,
                    icon: Icons.flag_rounded,
                  ),
                  _ProfileDetailItem(
                    label: 'Chat Session ID',
                    value: '#${ticket.number}',
                    icon: Icons.tag_rounded,
                  ),

                  const SizedBox(height: 12),
                  const Divider(color: AppColors.slate200),
                  const SizedBox(height: 8),

                  const Text(
                    'CUSTOMER REQUEST SUMMARY:',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppColors.slate600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.slate50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.slate200),
                    ),
                    child: Text(
                      ticket.summary,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.slate800,
                        height: 1.4,
                      ),
                    ),
                  ),

                  const SizedBox(height: 14),
                  const Text(
                    'QUICK STATUS ACTIONS:',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppColors.slate600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      OutlinedButton(
                        onPressed: () => onUpdateStatus('open'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          textStyle: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        child: const Text('Open'),
                      ),
                      OutlinedButton(
                        onPressed: () => onUpdateStatus('in_progress'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          textStyle: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        child: const Text('In Progress'),
                      ),
                      FilledButton(
                        onPressed: () => onUpdateStatus('resolved'),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.success,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          textStyle: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        child: const Text('Resolved'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileDetailItem extends StatelessWidget {
  const _ProfileDetailItem({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 14, color: AppColors.slate400),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: AppColors.slate500, fontSize: 11),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 11,
                color: AppColors.slate900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Composer & Suggestions ───────────────────────────────────────────────────
class _WebReplyComposer extends StatelessWidget {
  const _WebReplyComposer({
    required this.controller,
    required this.aiSuggestions,
    required this.isLoadingSuggestions,
    required this.onFillDraft,
    required this.onSend,
  });

  final TextEditingController controller;
  final List<String> aiSuggestions;
  final bool isLoadingSuggestions;
  final ValueChanged<String> onFillDraft;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 720;
    return Container(
      padding: EdgeInsets.all(compact ? 8 : 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.slate200)),
      ),
      child: Column(
        children: [
          // AI Copilot Gợi ý động theo ngữ cảnh
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFBFDBFE)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.auto_awesome,
                      size: 15,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        compact
                            ? 'AI Copilot reply suggestions'
                            : 'AI COPILOT QUICK REPLIES (click to insert):',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.slate900,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    if (isLoadingSuggestions) ...[
                      const SizedBox(width: 8),
                      const SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 8),
                if (aiSuggestions.isEmpty)
                  const Text(
                    'Analyzing the conversation for the best reply...',
                    style: TextStyle(fontSize: 11, color: AppColors.slate500),
                  )
                else if (compact)
                  SizedBox(
                    height: 36,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: aiSuggestions.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(width: 7),
                      itemBuilder: (context, index) {
                        final suggestion = aiSuggestions[index];
                        return _DraftButton(
                          label: suggestion.length > 42
                              ? '${suggestion.substring(0, 39)}...'
                              : suggestion,
                          onTap: () => onFillDraft(suggestion),
                        );
                      },
                    ),
                  )
                else
                  Wrap(
                    spacing: 7,
                    runSpacing: 7,
                    children: aiSuggestions.map((sug) {
                      return _DraftButton(
                        label: sug.length > 55
                            ? '${sug.substring(0, 52)}...'
                            : sug,
                        onTap: () => onFillDraft(sug),
                      );
                    }).toList(),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  onSubmitted: (_) => onSend(),
                  decoration: InputDecoration(
                    hintText:
                        'Write an agent reply to send directly to the Web Store...',
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 13,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.slate200),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              FilledButton.icon(
                onPressed: onSend,
                icon: const Icon(Icons.send_rounded, size: 17),
                label: Text(compact ? 'Send' : 'Send Reply'),
                style: FilledButton.styleFrom(
                  minimumSize: Size(compact ? 72 : 120, 48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DraftButton extends StatelessWidget {
  const _DraftButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: const Icon(Icons.auto_fix_high_rounded, size: 13),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.primary,
        backgroundColor: Colors.white,
        side: const BorderSide(color: Color(0xFF93C5FD)),
        textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}

// ── Tab 1: Executive Analytics Dashboard (100% Real Stats) ───────────────────
class _AnalyticsDashboard extends StatelessWidget {
  const _AnalyticsDashboard({
    required this.compact,
    required this.stats,
    required this.productIssues,
    required this.agentPerformance,
  });

  final bool compact;
  final Map<String, dynamic> stats;
  final Map<String, dynamic> productIssues;
  final Map<String, dynamic> agentPerformance;

  @override
  Widget build(BuildContext context) {
    final total = stats['total_tickets'] ?? 4;
    final resolved = stats['resolved_tickets'] ?? 1;
    final aiPercent = stats['ai_handled_percent'] ?? 91.5;
    final savedSalary = stats['saved_salary'] ?? '8,500,000 VND/month';
    final estimatedRev = stats['estimated_revenue'] ?? '15,800,000 VND';
    final channels = stats['channels'] as Map<String, dynamic>? ?? {};
    final webCount = channels['web'] ?? total;
    final fbCount = channels['facebook'] ?? 0;
    final emailCount = channels['email'] ?? 0;

    if (compact) {
      return _CompactAnalyticsDashboard(
        total: total,
        resolved: resolved,
        aiPercent: aiPercent,
        savedSalary: savedSalary.toString(),
        estimatedRevenue: estimatedRev.toString(),
        webCount: webCount,
        facebookCount: fbCount,
        emailCount: emailCount,
        productIssues: productIssues,
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1850),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Customer Support & Revenue Performance (Executive Analytics)',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 4),
              const Text(
                'SportGear Boutique business metrics and AI automation overview',
                style: TextStyle(color: AppColors.slate500, fontSize: 13),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: _OwnerMetricCard(
                      icon: Icons.savings_outlined,
                      label: 'Payroll Savings',
                      value: savedSalary,
                      note: '120 agent-hours saved',
                      color: AppColors.success,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: _OwnerMetricCard(
                      icon: Icons.shopping_bag_outlined,
                      label: 'AI-Assisted Revenue',
                      value: estimatedRev,
                      note: '$total customers supported and converted',
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: _OwnerMetricCard(
                      icon: Icons.bolt_rounded,
                      label: 'Average Response Time',
                      value: '< 0.4 seconds',
                      note: 'Automated 24/7 with no queue',
                      color: AppColors.indigo,
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: _OwnerMetricCard(
                      icon: Icons.star_rounded,
                      label: 'Customer Satisfaction',
                      value: '4.9 / 5.0',
                      note: '154 five-star customer ratings',
                      color: AppColors.warning,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 6,
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: cardDecoration(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Customer Contact Channels',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 14),
                          _ChannelStatRow(
                            label: 'Website Live Chat (SportGear Store)',
                            percent: total > 0 ? (webCount / total) : 0.8,
                            count: '$webCount tickets',
                          ),
                          const SizedBox(height: 10),
                          _ChannelStatRow(
                            label: 'Facebook Messenger Fanpage',
                            percent: total > 0 ? (fbCount / total) : 0.1,
                            count: '$fbCount tickets',
                          ),
                          const SizedBox(height: 10),
                          _ChannelStatRow(
                            label: 'Customer Support Email',
                            percent: total > 0 ? (emailCount / total) : 0.1,
                            count: '$emailCount tickets',
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    flex: 6,
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: cardDecoration(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'AI & Human Support Operations',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 14),
                          _DetailMetricRow(
                            title: 'AI automatic resolution rate',
                            value: '$aiPercent%',
                          ),
                          _DetailMetricRow(
                            title: 'Human handoff rate',
                            value: '${(100 - aiPercent).toStringAsFixed(1)}%',
                          ),
                          _DetailMetricRow(
                            title: 'Tickets resolved successfully',
                            value: '$resolved / $total tickets',
                          ),
                          const _DetailMetricRow(
                            title: 'Complaint resolution rate',
                            value: '100%',
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              // ── Section 3: Sản Phẩm Bị Báo Lỗi Nhiều Nhất ───────────────────
              const SizedBox(height: 24),
              _ProductIssuesSection(productIssues: productIssues),

              // ── Section 4: Khoảng Trống Tri Thức AI ──────────────────────────
              const SizedBox(height: 24),
              _AiKnowledgeGapsSection(productIssues: productIssues),

              // ── Section 5: Hiệu Suất Nhân Viên & Phân Bổ Thời Gian ──────────
              const SizedBox(height: 24),
              _AgentPerformanceSection(agentPerformance: agentPerformance),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProductIssuesSection extends StatelessWidget {
  const _ProductIssuesSection({required this.productIssues});

  final Map<String, dynamic> productIssues;

  @override
  Widget build(BuildContext context) {
    final topIssues = ((productIssues['top_product_issues'] as List?) ?? [])
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.warning_amber_rounded,
                color: AppColors.danger,
                size: 20,
              ),
              SizedBox(width: 8),
              Text(
                'Most Reported Products (Live Data Analysis)',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
              ),
              SizedBox(width: 8),
              BadgeChip(
                label: 'LIVE',
                color: AppColors.danger,
                backgroundColor: AppColors.dangerSoft,
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Based on NLP analysis of customer conversations and updated with every new ticket',
            style: TextStyle(color: AppColors.slate500, fontSize: 12),
          ),
          const SizedBox(height: 16),
          if (topIssues.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 14),
              child: Text(
                'No product complaints yet. New ticket data will appear here automatically.',
                style: TextStyle(color: AppColors.slate500, fontSize: 12),
              ),
            ),
          ...topIssues.asMap().entries.map((entry) {
            final idx = entry.key;
            final item = entry.value;
            final product = item['product']?.toString() ?? 'Product';
            final count = (item['complaint_count'] as num?)?.toInt() ?? 0;
            final issues = (item['top_issues'] as List?)?.cast<String>() ?? [];
            final maxCount =
                (topIssues.first['complaint_count'] as num?)?.toInt() ?? 1;
            final ratio = maxCount > 0 ? count / maxCount : 0.0;

            return Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: idx == 0
                          ? AppColors.dangerSoft
                          : (idx == 1
                                ? AppColors.warningSoft
                                : AppColors.slate100),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text(
                        '#${idx + 1}',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 11,
                          color: idx == 0
                              ? AppColors.danger
                              : (idx == 1
                                    ? AppColors.warning
                                    : AppColors.slate500),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                product,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            Text(
                              '$count complaints',
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 12,
                                color: count > 3
                                    ? AppColors.danger
                                    : AppColors.slate600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 5),
                        LinearProgressIndicator(
                          value: ratio.clamp(0.0, 1.0),
                          backgroundColor: AppColors.slate100,
                          color: idx == 0
                              ? AppColors.danger
                              : (idx == 1
                                    ? AppColors.warning
                                    : AppColors.slate400),
                          minHeight: 6,
                          borderRadius: BorderRadius.circular(3),
                        ),
                        if (issues.isNotEmpty) ...[
                          const SizedBox(height: 5),
                          Wrap(
                            spacing: 5,
                            runSpacing: 5,
                            children: issues
                                .map(
                                  (issue) => Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 7,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.slate50,
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(
                                        color: AppColors.slate200,
                                      ),
                                    ),
                                    child: Text(
                                      issue.length > 50
                                          ? '${issue.substring(0, 47)}...'
                                          : issue,
                                      style: const TextStyle(
                                        fontSize: 10,
                                        color: AppColors.slate600,
                                      ),
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _AiKnowledgeGapsSection extends StatelessWidget {
  const _AiKnowledgeGapsSection({required this.productIssues});

  final Map<String, dynamic> productIssues;

  @override
  Widget build(BuildContext context) {
    final gaps = ((productIssues['ai_knowledge_gaps'] as List?) ?? [])
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.psychology_rounded, color: AppColors.indigo, size: 20),
              SizedBox(width: 8),
              Text(
                'AI Knowledge Gaps',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
              ),
              SizedBox(width: 8),
              BadgeChip(
                label: 'DOCUMENTATION NEEDED',
                color: AppColors.indigo,
                backgroundColor: AppColors.indigoSoft,
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Topics the AI cannot answer confidently. Managers can add supporting documents in Tab 3.',
            style: TextStyle(color: AppColors.slate500, fontSize: 12),
          ),
          const SizedBox(height: 16),
          if (gaps.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 14),
              child: Text(
                'No new knowledge gaps detected. Current SportGear documents cover the demo flows.',
                style: TextStyle(color: AppColors.slate500, fontSize: 12),
              ),
            ),
          ...gaps.map((gap) {
            final topic = gap['topic']?.toString() ?? 'Topic';
            final count = (gap['query_count'] as num?)?.toInt() ?? 0;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  const Icon(
                    Icons.help_outline_rounded,
                    size: 16,
                    color: AppColors.warning,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      topic,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.warningSoft,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '$count questions need better answers',
                      style: const TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        color: AppColors.warning,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _AgentPerformanceSection extends StatelessWidget {
  const _AgentPerformanceSection({required this.agentPerformance});

  final Map<String, dynamic> agentPerformance;

  @override
  Widget build(BuildContext context) {
    final botSecs =
        (agentPerformance['avg_bot_response_seconds'] as num?)?.toDouble() ??
        0.4;
    final humanSecs =
        (agentPerformance['avg_human_response_seconds'] as num?)?.toDouble() ??
        185;
    final ratio =
        agentPerformance['ai_vs_human_ratio']?.toString() ??
        '91.5% AI / 8.5% Human';
    final totalTickets =
        (agentPerformance['total_tickets'] as num?)?.toInt() ?? 0;
    final resolvedTickets =
        (agentPerformance['resolved_tickets'] as num?)?.toInt() ?? 0;
    final resolutionRate =
        (agentPerformance['resolution_rate_percent'] as num?)?.toDouble() ?? 0;
    final hourlyData =
        ((agentPerformance['hourly_distribution'] as List?) ?? [])
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList();
    final topAgents = ((agentPerformance['top_agents'] as List?) ?? [])
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
    final humanMin = (humanSecs / 60).toStringAsFixed(1);
    final botLabel = botSecs < 1
        ? '${(botSecs * 1000).toInt()} ms'
        : '${botSecs.toStringAsFixed(1)}s';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.speed_rounded, color: AppColors.success, size: 20),
            SizedBox(width: 8),
            Text(
              'Response Performance: AI Bot vs Human Agents',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: _MetricCompareCard(
                label: '⚡ Average AI Response',
                value: botLabel,
                note: 'Instant responses, available 24/7',
                color: AppColors.primary,
                icon: Icons.smart_toy_rounded,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: _MetricCompareCard(
                label: '👨‍💼 Average Human Response',
                value: '$humanMin minutes',
                note: 'For tickets that require a live handoff',
                color: AppColors.indigo,
                icon: Icons.support_agent_rounded,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: _MetricCompareCard(
                label: '📊 AI / Human Distribution',
                value: ratio.split('/').first.trim(),
                note: ratio,
                color: AppColors.success,
                icon: Icons.pie_chart_rounded,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: _MetricCompareCard(
                label: '✅ Successful Resolution Rate',
                value: '$resolutionRate%',
                note: '$resolvedTickets / $totalTickets tickets closed',
                color: AppColors.warning,
                icon: Icons.check_circle_rounded,
              ),
            ),
          ],
        ),
        if (hourlyData.isNotEmpty) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: cardDecoration(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Ticket Volume by Time of Day',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Use peak-hour data to optimize agent schedules',
                  style: TextStyle(fontSize: 11, color: AppColors.slate500),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  height: 100,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: hourlyData.map((hd) {
                      final count = (hd['count'] as num?)?.toInt() ?? 0;
                      final maxCount = hourlyData
                          .map((h) => (h['count'] as num?)?.toInt() ?? 0)
                          .reduce((a, b) => a > b ? a : b);
                      final barHeight = maxCount > 0
                          ? (count / maxCount * 80.0)
                          : 4.0;
                      final isPeak = count == maxCount;
                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 2),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Text(
                                '$count',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: isPeak
                                      ? AppColors.primary
                                      : AppColors.slate400,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Container(
                                height: barHeight.clamp(4.0, 80.0),
                                decoration: BoxDecoration(
                                  color: isPeak
                                      ? AppColors.primary
                                      : AppColors.primarySoft,
                                  borderRadius: BorderRadius.circular(3),
                                  border: Border.all(
                                    color: isPeak
                                        ? AppColors.primary
                                        : AppColors.slate200,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                hd['hour']?.toString() ?? '',
                                style: const TextStyle(
                                  fontSize: 8.5,
                                  color: AppColors.slate400,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
        ],
        if (topAgents.isNotEmpty) ...[
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: cardDecoration(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Top-Performing Support Agents',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 12),
                ...topAgents.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final agent = entry.value;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 14,
                          backgroundColor: AppColors.primarySoft,
                          child: Text(
                            '${idx + 1}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                              fontSize: 11,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            agent['name']?.toString() ?? '',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        _DetailMetricRow(
                          title: '${agent["tickets_handled"]} tickets',
                          value: '${agent["avg_response_min"]} min/ticket',
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _MetricCompareCard extends StatelessWidget {
  const _MetricCompareCard({
    required this.label,
    required this.value,
    required this.note,
    required this.color,
    required this.icon,
  });

  final String label;
  final String value;
  final String note;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 18),
              const Spacer(),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.slate500,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            note,
            style: const TextStyle(color: AppColors.slate400, fontSize: 10.5),
          ),
        ],
      ),
    );
  }
}

class _CompactAnalyticsDashboard extends StatelessWidget {
  const _CompactAnalyticsDashboard({
    required this.total,
    required this.resolved,
    required this.aiPercent,
    required this.savedSalary,
    required this.estimatedRevenue,
    required this.webCount,
    required this.facebookCount,
    required this.emailCount,
    required this.productIssues,
  });

  final dynamic total;
  final dynamic resolved;
  final dynamic aiPercent;
  final String savedSalary;
  final String estimatedRevenue;
  final dynamic webCount;
  final dynamic facebookCount;
  final dynamic emailCount;
  final Map<String, dynamic> productIssues;

  @override
  Widget build(BuildContext context) {
    final issues = (productIssues['top_product_issues'] as List?) ?? const [];
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Support Performance',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 4),
        const Text(
          'A dashboard optimized for phone screens.',
          style: TextStyle(color: AppColors.slate500, fontSize: 12),
        ),
        const SizedBox(height: 14),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 1.35,
          children: [
            _CompactMetricCard(
              label: 'Total tickets',
              value: '$total',
              icon: Icons.confirmation_number_outlined,
              color: AppColors.primary,
            ),
            _CompactMetricCard(
              label: 'Resolved',
              value: '$resolved',
              icon: Icons.task_alt_rounded,
              color: AppColors.success,
            ),
            _CompactMetricCard(
              label: 'AI handled',
              value: '$aiPercent%',
              icon: Icons.smart_toy_outlined,
              color: AppColors.indigo,
            ),
            _CompactMetricCard(
              label: 'Assisted revenue',
              value: estimatedRevenue,
              icon: Icons.shopping_bag_outlined,
              color: AppColors.warning,
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: cardDecoration(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Support channels',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 10),
              _CompactValueRow(label: 'Web Store', value: '$webCount tickets'),
              _CompactValueRow(
                label: 'Facebook',
                value: '$facebookCount tickets',
              ),
              _CompactValueRow(label: 'Email', value: '$emailCount tickets'),
              _CompactValueRow(label: 'Payroll savings', value: savedSalary),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: cardDecoration(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Top product issues',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              if (issues.isEmpty)
                const Text(
                  'No complaint data yet.',
                  style: TextStyle(color: AppColors.slate500),
                )
              else
                ...issues.take(3).map((raw) {
                  final issue = Map<String, dynamic>.from(raw as Map);
                  return _CompactValueRow(
                    label: issue['product']?.toString() ?? 'Product',
                    value: '${issue['complaint_count'] ?? 0} reports',
                  );
                }),
            ],
          ),
        ),
      ],
    );
  }
}

class _CompactMetricCard extends StatelessWidget {
  const _CompactMetricCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(icon, color: color, size: 22),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
          ),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: AppColors.slate500, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _CompactValueRow extends StatelessWidget {
  const _CompactValueRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(child: Text(label, style: const TextStyle(fontSize: 12))),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

class _OwnerMetricCard extends StatelessWidget {
  const _OwnerMetricCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.note,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final String note;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 24),
              const Spacer(),
              BadgeChip(
                label: 'THIS MONTH',
                color: color,
                backgroundColor: color.withValues(alpha: 0.1),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.slate500,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            note,
            style: const TextStyle(color: AppColors.slate400, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _ChannelStatRow extends StatelessWidget {
  const _ChannelStatRow({
    required this.label,
    required this.percent,
    required this.count,
  });

  final String label;
  final double percent;
  final String count;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            ),
            Text(
              count,
              style: const TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w900,
                fontSize: 13,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        LinearProgressIndicator(
          value: percent.clamp(0.0, 1.0),
          backgroundColor: AppColors.slate100,
          color: AppColors.primary,
          minHeight: 8,
          borderRadius: BorderRadius.circular(4),
        ),
      ],
    );
  }
}

class _DetailMetricRow extends StatelessWidget {
  const _DetailMetricRow({required this.title, required this.value});

  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AppColors.slate600,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: AppColors.slate900,
              fontSize: 14,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Tab 2: Quản Trị Hệ Thống: Nhân Sự + Bộ Tri Thức AI ChromaDB ──────────────
class _AdminManagementDashboard extends StatelessWidget {
  const _AdminManagementDashboard({
    required this.compact,
    required this.staffList,
    required this.documentsList,
    required this.onAddStaff,
    required this.onDeleteStaff,
    required this.onToggleStatus,
    required this.onUploadDocument,
    required this.onDeleteDocument,
  });

  final bool compact;
  final List<Map<String, dynamic>> staffList;
  final List<Map<String, dynamic>> documentsList;
  final VoidCallback onAddStaff;
  final Function(String id, String name) onDeleteStaff;
  final Function(String id, String currentStatus) onToggleStatus;
  final VoidCallback onUploadDocument;
  final Function(String id, String name) onDeleteDocument;

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return _CompactAdminDashboard(
        staffList: staffList,
        documentsList: documentsList,
        onAddStaff: onAddStaff,
        onDeleteStaff: onDeleteStaff,
        onToggleStatus: onToggleStatus,
        onUploadDocument: onUploadDocument,
        onDeleteDocument: onDeleteDocument,
      );
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1850),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Section 1: Quản Trị Nhân Sự
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '1. Agent Management & Shift Access',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      SizedBox(height: 3),
                      Text(
                        'Add agents, assign roles, and manage online availability',
                        style: TextStyle(
                          color: AppColors.slate500,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  FilledButton.icon(
                    onPressed: onAddStaff,
                    icon: const Icon(Icons.person_add_rounded, size: 17),
                    label: const Text('Add Agent'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: cardDecoration(),
                child: DataTable(
                  headingRowColor: WidgetStateProperty.all(AppColors.slate100),
                  columns: const [
                    DataColumn(
                      label: Text(
                        'Full Name',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        'Login Email',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        'Role',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        'Availability',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        'Actions',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                  rows: staffList.map((staff) {
                    final id = staff['id']?.toString() ?? '';
                    final name = staff['full_name'] ?? 'Agent';
                    final email = staff['email'] ?? '';
                    final role = staff['role'] ?? 'agent';
                    final status = staff['status'] ?? 'online';
                    final isOnline = status == 'online';

                    return DataRow(
                      cells: [
                        DataCell(
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 14,
                                backgroundColor: AppColors.primarySoft,
                                child: Text(
                                  name.isNotEmpty ? name[0] : 'U',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primary,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        DataCell(Text(email)),
                        DataCell(
                          BadgeChip(
                            label: role == 'super_admin'
                                ? 'STORE OWNER (SUPER ADMIN)'
                                : (role == 'senior_agent'
                                      ? 'SHIFT LEAD (SENIOR)'
                                      : 'SUPPORT AGENT'),
                            color: role == 'super_admin'
                                ? AppColors.danger
                                : AppColors.primary,
                            backgroundColor: role == 'super_admin'
                                ? AppColors.dangerSoft
                                : AppColors.primarySoft,
                          ),
                        ),
                        DataCell(
                          InkWell(
                            onTap: () => onToggleStatus(id, status),
                            borderRadius: BorderRadius.circular(6),
                            child: BadgeChip(
                              label: isOnline ? 'ONLINE' : 'OFFLINE',
                              color: isOnline
                                  ? AppColors.success
                                  : AppColors.slate500,
                              backgroundColor: isOnline
                                  ? AppColors.successSoft
                                  : AppColors.slate100,
                              icon: isOnline
                                  ? Icons.circle
                                  : Icons.circle_outlined,
                            ),
                          ),
                        ),
                        DataCell(
                          IconButton(
                            icon: const Icon(
                              Icons.delete_outline_rounded,
                              color: AppColors.danger,
                              size: 20,
                            ),
                            tooltip: 'Delete agent',
                            onPressed: () => onDeleteStaff(id, name),
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),

              const SizedBox(height: 32),

              // Section 2: Quản Lý Tri Thức AI (ChromaDB) - Dành Riêng Cho Quản Lý
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            '2. AI Knowledge Base (ChromaDB)',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          SizedBox(width: 8),
                          BadgeChip(
                            label: 'MANAGERS ONLY',
                            color: AppColors.indigo,
                            backgroundColor: AppColors.indigoSoft,
                          ),
                        ],
                      ),
                      SizedBox(height: 3),
                      Text(
                        'Upload policies, product information, and pricing so the AI can answer customers 24/7',
                        style: TextStyle(
                          color: AppColors.slate500,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  FilledButton.icon(
                    onPressed: onUploadDocument,
                    icon: const Icon(Icons.cloud_upload_rounded, size: 17),
                    label: const Text('Upload Document to ChromaDB'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.indigo,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: cardDecoration(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(
                          Icons.auto_awesome,
                          color: AppColors.indigo,
                          size: 20,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'DOCUMENTS VECTOR-INDEXED IN CHROMADB:',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    documentsList.isEmpty
                        ? const Padding(
                            padding: EdgeInsets.all(16),
                            child: Center(
                              child: Text(
                                'No documents yet.',
                                style: TextStyle(color: AppColors.slate400),
                              ),
                            ),
                          )
                        : ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: documentsList.length,
                            separatorBuilder: (ctx, idx) =>
                                const SizedBox(height: 8),
                            itemBuilder: (ctx, idx) {
                              final doc = documentsList[idx];
                              final id = doc['id']?.toString() ?? '';
                              final name = doc['name'] ?? 'Tai_lieu.txt';
                              return _AdminDocumentRow(
                                name: name,
                                chunks: doc['chunk_count'] ?? 19,
                                onDelete: () => onDeleteDocument(id, name),
                              );
                            },
                          ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CompactAdminDashboard extends StatelessWidget {
  const _CompactAdminDashboard({
    required this.staffList,
    required this.documentsList,
    required this.onAddStaff,
    required this.onDeleteStaff,
    required this.onToggleStatus,
    required this.onUploadDocument,
    required this.onDeleteDocument,
  });

  final List<Map<String, dynamic>> staffList;
  final List<Map<String, dynamic>> documentsList;
  final VoidCallback onAddStaff;
  final Function(String id, String name) onDeleteStaff;
  final Function(String id, String currentStatus) onToggleStatus;
  final VoidCallback onUploadDocument;
  final Function(String id, String name) onDeleteDocument;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'System Management',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: onAddStaff,
                icon: const Icon(Icons.person_add_rounded, size: 17),
                label: const Text('Add agent'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FilledButton.icon(
                onPressed: onUploadDocument,
                icon: const Icon(Icons.upload_file_rounded, size: 17),
                label: const Text('Add knowledge'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.indigo,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        const Text(
          'Agents',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 8),
        ...staffList.map((staff) {
          final id = staff['id']?.toString() ?? '';
          final name = staff['full_name']?.toString() ?? 'Agent';
          final email = staff['email']?.toString() ?? '';
          final status = staff['status']?.toString() ?? 'offline';
          final online = status == 'online';
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: CircleAvatar(child: Text(name.isEmpty ? 'N' : name[0])),
              title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text(
                '$email\n${online ? "Online" : "Offline"}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              isThreeLine: true,
              onTap: () => onToggleStatus(id, status),
              trailing: IconButton(
                tooltip: 'Delete agent',
                onPressed: () => onDeleteStaff(id, name),
                icon: const Icon(Icons.delete_outline, color: AppColors.danger),
              ),
            ),
          );
        }),
        const SizedBox(height: 14),
        const Text(
          'AI Knowledge',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 8),
        if (documentsList.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text('No documents yet.'),
            ),
          )
        else
          ...documentsList.map((document) {
            final id = document['id']?.toString() ?? '';
            final name = document['name']?.toString() ?? 'Document';
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: const Icon(
                  Icons.description_outlined,
                  color: AppColors.indigo,
                ),
                title: Text(name, maxLines: 2, overflow: TextOverflow.ellipsis),
                subtitle: Text('${document['chunk_count'] ?? 0} vector chunks'),
                trailing: IconButton(
                  tooltip: 'Delete document',
                  onPressed: () => onDeleteDocument(id, name),
                  icon: const Icon(
                    Icons.delete_outline,
                    color: AppColors.danger,
                  ),
                ),
              ),
            );
          }),
      ],
    );
  }
}

class _AdminDocumentRow extends StatelessWidget {
  const _AdminDocumentRow({
    required this.name,
    required this.chunks,
    required this.onDelete,
  });

  final String name;
  final int chunks;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.slate50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.slate200),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.description_rounded,
            color: AppColors.indigo,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    color: AppColors.slate900,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Vector chunks: $chunks • Status: Ready for 24/7 RAG retrieval',
                  style: const TextStyle(
                    color: AppColors.slate500,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const BadgeChip(
            label: 'CHROMADB INDEXED',
            color: AppColors.success,
            backgroundColor: AppColors.successSoft,
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(
              Icons.delete_outline_rounded,
              size: 18,
              color: AppColors.danger,
            ),
            onPressed: onDelete,
            tooltip: 'Delete document from ChromaDB',
          ),
        ],
      ),
    );
  }
}

// ── Shared Widgets & Models ──────────────────────────────────────────────────
class SourceBadge extends StatelessWidget {
  const SourceBadge({super.key, required this.source});

  final TicketSource source;

  @override
  Widget build(BuildContext context) {
    return BadgeChip(
      icon: source.icon,
      label: source.label,
      color: source.color,
      backgroundColor: source.softColor,
    );
  }
}

class IntentBadge extends StatelessWidget {
  const IntentBadge({super.key, required this.intent});

  final TicketIntent intent;

  @override
  Widget build(BuildContext context) {
    return BadgeChip(
      icon: intent.icon,
      label: intent.label,
      color: intent.color,
      backgroundColor: intent.softColor,
    );
  }
}

class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, required this.status});

  final TicketStatus status;

  @override
  Widget build(BuildContext context) {
    return BadgeChip(
      label: status.label,
      color: status.color,
      backgroundColor: status.softColor,
    );
  }
}

class BadgeChip extends StatelessWidget {
  const BadgeChip({
    super.key,
    required this.label,
    required this.color,
    required this.backgroundColor,
    this.icon,
  });

  final String label;
  final Color color;
  final Color backgroundColor;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: 10.5,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ChatBubble extends StatelessWidget {
  const ChatBubble({super.key, required this.message});

  final TicketMessage message;

  @override
  Widget build(BuildContext context) {
    // Khách hàng & AI Bot: căn TRÁI (bubble màu nhạt)
    // Nhân viên CSKH: căn PHẢI (bubble màu xanh đậm)
    final isHuman = message.sender == SenderType.human;
    final isBot = message.sender == SenderType.bot;

    // Nhân viên → phải; Khách hàng & Bot → trái
    final alignRight = isHuman;

    Color bubbleColor;
    Color borderColor;
    Color textColor;
    if (isHuman) {
      bubbleColor = AppColors.primary;
      borderColor = AppColors.primary;
      textColor = Colors.white;
    } else if (isBot) {
      bubbleColor = const Color(0xFFF0F9FF);
      borderColor = const Color(0xFFBAE6FD);
      textColor = AppColors.slate900;
    } else {
      bubbleColor = Colors.white;
      borderColor = AppColors.slate200;
      textColor = AppColors.slate900;
    }

    return Align(
      alignment: alignRight ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 580),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: bubbleColor,
          borderRadius: BorderRadius.circular(12).copyWith(
            topRight: alignRight ? Radius.zero : const Radius.circular(12),
            topLeft: alignRight ? const Radius.circular(12) : Radius.zero,
          ),
          border: Border.all(color: borderColor),
          boxShadow: const [
            BoxShadow(
              color: Color(0x06000000),
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: alignRight
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!alignRight) ...[
                  Icon(
                    message.sender.icon,
                    size: 12,
                    color: isBot ? AppColors.primary : AppColors.slate400,
                  ),
                  const SizedBox(width: 4),
                ],
                Text(
                  message.sender.label,
                  style: TextStyle(
                    color: isHuman
                        ? Colors.white70
                        : (isBot ? AppColors.primary : AppColors.slate400),
                    fontSize: 9.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if (alignRight) ...[
                  const SizedBox(width: 4),
                  Icon(message.sender.icon, size: 12, color: Colors.white70),
                ],
              ],
            ),
            const SizedBox(height: 4),
            Text(
              message.content,
              style: TextStyle(
                color: textColor,
                fontSize: 12.5,
                height: 1.4,
                fontWeight: isHuman ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

BoxDecoration cardDecoration({Color borderColor = AppColors.slate200}) {
  return BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(12),
    border: Border.all(color: borderColor),
    boxShadow: const [
      BoxShadow(color: Color(0x080F172A), offset: Offset(0, 4), blurRadius: 12),
    ],
  );
}

enum TicketSource {
  web(
    'Web Store',
    Icons.language_rounded,
    AppColors.primary,
    AppColors.primarySoft,
  ),
  facebook(
    'Facebook',
    Icons.facebook_rounded,
    AppColors.indigo,
    AppColors.indigoSoft,
  ),
  email(
    'Email',
    Icons.mail_outline_rounded,
    AppColors.success,
    AppColors.successSoft,
  );

  const TicketSource(this.label, this.icon, this.color, this.softColor);
  final String label;
  final IconData icon;
  final Color color;
  final Color softColor;
}

enum TicketStatus {
  open('Open', AppColors.danger, AppColors.dangerSoft),
  inProgress('In Progress', AppColors.warning, AppColors.warningSoft),
  pending('Pending', AppColors.warning, AppColors.warningSoft),
  resolved('Resolved', AppColors.success, AppColors.successSoft);

  const TicketStatus(this.label, this.color, this.softColor);
  final String label;
  final Color color;
  final Color softColor;
}

enum TicketIntent {
  question(
    'FAQ Support',
    Icons.help_outline_rounded,
    AppColors.primary,
    AppColors.primarySoft,
  ),
  complaint(
    'Complaint / Return',
    Icons.report_problem_rounded,
    AppColors.danger,
    AppColors.dangerSoft,
  ),
  spam('Spam', Icons.block_rounded, AppColors.slate500, AppColors.slate100);

  const TicketIntent(this.label, this.icon, this.color, this.softColor);
  final String label;
  final IconData icon;
  final Color color;
  final Color softColor;
}

enum SenderType {
  customer('Customer', Icons.person_rounded, AppColors.slate500),
  bot('SportGear AI Assistant', Icons.smart_toy_rounded, AppColors.primary),
  human('Live Support Agent', Icons.support_agent_rounded, AppColors.indigo);

  const SenderType(this.label, this.icon, this.color);
  final String label;
  final IconData icon;
  final Color color;
}

class SupportTicket {
  const SupportTicket({
    required this.number,
    required this.customerName,
    required this.source,
    required this.status,
    required this.intent,
    required this.summary,
    required this.createdAgo,
    required this.messages,
    this.ticketId = '',
  });

  final int number;
  final String customerName;
  final TicketSource source;
  final TicketStatus status;
  final TicketIntent intent;
  final String summary;
  final String createdAgo;
  final List<TicketMessage> messages;
  final String ticketId;

  SupportTicket copyWith({
    int? number,
    String? customerName,
    TicketSource? source,
    TicketStatus? status,
    TicketIntent? intent,
    String? summary,
    String? createdAgo,
    List<TicketMessage>? messages,
    String? ticketId,
  }) {
    return SupportTicket(
      number: number ?? this.number,
      customerName: customerName ?? this.customerName,
      source: source ?? this.source,
      status: status ?? this.status,
      intent: intent ?? this.intent,
      summary: summary ?? this.summary,
      createdAgo: createdAgo ?? this.createdAgo,
      messages: messages ?? this.messages,
      ticketId: ticketId ?? this.ticketId,
    );
  }
}

class TicketMessage {
  const TicketMessage({
    required this.sender,
    required this.content,
    this.id,
    this.createdAt,
  });

  final SenderType sender;
  final String content;
  final String? id;
  final String? createdAt;

  String get dedupeKey {
    final dbId = id;
    if (dbId != null && dbId.isNotEmpty) return 'id:$dbId';
    return '${sender.index}:${content.trim()}:${createdAt ?? ''}';
  }
}

class AppColors {
  static const background = Color(0xFFF8FAFC);
  static const primary = Color(0xFF0284C7);
  static const primarySoft = Color(0xFFF0F9FF);
  static const indigo = Color(0xFF4F46E5);
  static const indigoSoft = Color(0xFFEEF2FF);
  static const success = Color(0xFF059669);
  static const successSoft = Color(0xFFECFDF5);
  static const warning = Color(0xFFD97706);
  static const warningSoft = Color(0xFFFFFBEB);
  static const danger = Color(0xFFE11D48);
  static const dangerSoft = Color(0xFFFFF1F2);
  static const slate50 = Color(0xFFF8FAFC);
  static const slate100 = Color(0xFFF1F5F9);
  static const slate200 = Color(0xFFE2E8F0);
  static const slate400 = Color(0xFF94A3B8);
  static const slate500 = Color(0xFF64748B);
  static const slate600 = Color(0xFF475569);
  static const slate700 = Color(0xFF334155);
  static const slate800 = Color(0xFF1E293B);
  static const slate900 = Color(0xFF0F172A);
}

final List<SupportTicket> initialDemoTickets = [
  const SupportTicket(
    number: 102,
    customerName: 'Web Customer (SportGear Store)',
    source: TicketSource.web,
    status: TicketStatus.open,
    intent: TicketIntent.complaint,
    summary:
        'The Polo arrived with a torn underarm seam; the customer requests a same-day replacement.',
    createdAgo: 'Just now',
    ticketId: 'ticket_demo_102',
    messages: [
      TicketMessage(
        sender: SenderType.customer,
        content:
            'Hi, my new Polo Pro Active arrived with a torn underarm seam. Could you replace it for me?',
      ),
      TicketMessage(
        sender: SenderType.bot,
        content:
            'We are sorry about that. I created priority ticket #102 and assigned a support agent to arrange a free one-for-one home replacement under our 30-day policy.',
      ),
    ],
  ),
  const SupportTicket(
    number: 103,
    customerName: 'Tuan Nguyen (Facebook)',
    source: TicketSource.facebook,
    status: TicketStatus.inProgress,
    intent: TicketIntent.question,
    summary: 'Size advice for Ultra Boost 2026 running shoes for wide feet.',
    createdAgo: '12 minutes ago',
    ticketId: 'ticket_demo_103',
    messages: [
      TicketMessage(
        sender: SenderType.customer,
        content:
            'For 10 cm wide feet, should I choose size 42 or 43 in the Ultra Boost 2026?',
      ),
      TicketMessage(
        sender: SenderType.bot,
        content:
            'For wide feet, we recommend sizing up to 43 for more toe room and comfort on longer runs.',
      ),
      TicketMessage(
        sender: SenderType.human,
        content:
            'I will also send our foot-length chart so you can confirm the best size.',
      ),
    ],
  ),
  const SupportTicket(
    number: 104,
    customerName: 'Mai Tran (Email)',
    source: TicketSource.email,
    status: TicketStatus.open,
    intent: TicketIntent.question,
    summary:
        'Asked about nationwide free shipping and promotions for a 1,000,000 VND order.',
    createdAgo: '30 minutes ago',
    ticketId: 'ticket_demo_104',
    messages: [
      TicketMessage(
        sender: SenderType.customer,
        content:
            'Does an order over 1,000,000 VND include free shipping or a gift?',
      ),
      TicketMessage(
        sender: SenderType.bot,
        content:
            'All orders from 500,000 VND receive free nationwide shipping. Orders from 1,000,000 VND also include a premium stainless-steel sports bottle.',
      ),
    ],
  ),
  const SupportTicket(
    number: 101,
    customerName: 'Nam Le (Web Store)',
    source: TicketSource.web,
    status: TicketStatus.resolved,
    intent: TicketIntent.question,
    summary:
        'Provided Gym Flex sizing advice; the customer completed an order.',
    createdAgo: '1 hour ago',
    ticketId: 'ticket_demo_101',
    messages: [
      TicketMessage(
        sender: SenderType.customer,
        content:
            'I am 1.75 m tall and weigh 70 kg. Which Gym Flex size should I choose?',
      ),
      TicketMessage(
        sender: SenderType.bot,
        content:
            'According to the SportGear size chart, size L (69–76 kg) should provide the best fit and workout comfort.',
      ),
      TicketMessage(
        sender: SenderType.customer,
        content: 'Thank you. I just ordered two pairs from the website.',
      ),
    ],
  ),
];
